import '../entities/job.dart';

/// Mirrors the database invariant before a builder submits a vacancy.
String? validateJob(Job job) {
  if (!job.isApprenticeship) return null;
  if (!job.openToApprentices) return 'Apprenticeships must accept apprentices.';
  if (job.pricingUnit != PricingUnit.hourly ||
      job.pricingType != PricingType.builderSet) {
    return 'Set an hourly pay amount for this apprenticeship.';
  }
  final amount = job.budgetAmount;
  if (amount == null || !amount.isFinite || amount <= 0) {
    return 'Enter a positive hourly pay amount.';
  }
  return null;
}
