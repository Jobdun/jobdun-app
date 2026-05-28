enum AdminJobStatusFilter { all, draft, open, filled, closed, cancelled }

String? adminJobStatusFilterToDb(AdminJobStatusFilter f) => switch (f) {
      AdminJobStatusFilter.all => null,
      AdminJobStatusFilter.draft => 'draft',
      AdminJobStatusFilter.open => 'open',
      AdminJobStatusFilter.filled => 'filled',
      AdminJobStatusFilter.closed => 'closed',
      AdminJobStatusFilter.cancelled => 'cancelled',
    };
