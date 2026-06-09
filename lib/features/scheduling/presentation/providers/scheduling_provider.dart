import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/create_booking.dart';
import '../../domain/usecases/get_my_bookings.dart';
import '../../domain/usecases/update_booking_status.dart';

// ── Data layer (public so tests can override) ─────────────────────────────────
final bookingDatasourceProvider = Provider<BookingRemoteDataSource>(
  (ref) => BookingRemoteDataSourceImpl(SupabaseConfig.client),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepositoryImpl(ref.read(bookingDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final createBookingUseCaseProvider = Provider(
  (ref) => CreateBooking(ref.read(bookingRepositoryProvider)),
);
final getMyBookingsUseCaseProvider = Provider(
  (ref) => GetMyBookings(ref.read(bookingRepositoryProvider)),
);
final updateBookingStatusUseCaseProvider = Provider(
  (ref) => UpdateBookingStatus(ref.read(bookingRepositoryProvider)),
);

// ── Reads ─────────────────────────────────────────────────────────────────────
/// Every booking the signed-in user is party to (as builder or trade).
final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((
  ref,
) async {
  final uid = readCurrentUserId(ref);
  if (uid == null) return const [];
  final result = await ref.read(getMyBookingsUseCaseProvider).call(uid);
  return result.fold((f) => throw Exception(f.message), (l) => l);
});

// ── Actions ───────────────────────────────────────────────────────────────────
final bookingActionsProvider = Provider(BookingActions.new);

class BookingActions {
  BookingActions(this._ref);
  final Ref _ref;

  Future<bool> create({
    required String jobId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  }) async {
    final builderId = readCurrentUserId(_ref);
    if (builderId == null) return false;
    final result = await _ref
        .read(createBookingUseCaseProvider)
        .call(
          jobId: jobId,
          builderId: builderId,
          tradeId: tradeId,
          scheduledDate: scheduledDate,
          note: note,
        );
    if (result.isRight()) _ref.invalidate(myBookingsProvider);
    return result.isRight();
  }

  Future<bool> setStatus(String bookingId, BookingStatus status) async {
    final result = await _ref
        .read(updateBookingStatusUseCaseProvider)
        .call(bookingId, status);
    if (result.isRight()) _ref.invalidate(myBookingsProvider);
    return result.isRight();
  }
}
