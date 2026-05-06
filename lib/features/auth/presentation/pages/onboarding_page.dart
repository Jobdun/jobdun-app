import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  final _locationController = TextEditingController();
  final _companyNameController = TextEditingController();

  int _currentPage = 0;
  UserRole? _selectedRole;
  String? _businessType;
  String? _tradeCategory;
  String? _yearsExperience;

  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _locationController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
    );
  }

  void _finish() {
    final role = _selectedRole;
    if (role == null) return;
    ref.read(authControllerProvider.notifier).completeOnboarding(
      role,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      companyName: _companyNameController.text.trim().isEmpty
          ? null
          : _companyNameController.text.trim(),
      businessType: _businessType,
      tradeCategory: _tradeCategory,
      yearsExperience: _yearsExperience,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(authControllerProvider.select((s) => s.isLoading));

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      const _WelcomePage(),
                      _RolePage(
                        selectedRole: _selectedRole,
                        onRoleChanged: (role) =>
                            setState(() => _selectedRole = role),
                      ),
                      _ProfileSetupPage(
                        role: _selectedRole,
                        locationController: _locationController,
                        companyNameController: _companyNameController,
                        selectedBusinessType: _businessType,
                        selectedTradeCategory: _tradeCategory,
                        selectedYearsExp: _yearsExperience,
                        onBusinessTypeChanged: (v) =>
                            setState(() => _businessType = v),
                        onTradeCategoryChanged: (v) =>
                            setState(() => _tradeCategory = v),
                        onYearsExpChanged: (v) =>
                            setState(() => _yearsExperience = v),
                      ),
                      const _AllSetPage(),
                    ],
                  ),
                ),
                _BottomBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  selectedRole: _selectedRole,
                  isLoading: isLoading,
                  pageController: _pageController,
                  onNext: _next,
                  onFinish: _finish,
                ),
              ],
            ),
            if (_currentPage == 0)
              Positioned(
                top: 16.h,
                right: 20.w,
                child: TextButton(
                  onPressed: _next,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text2,
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, 36.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.barlow(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Page 0: Welcome ────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'lib/core/assets/mark-jobdun.svg',
            width: 80.r,
            height: 80.r,
          ),
          Gap(32.h),
          Text(
            'GET WORK.\nPOST JOBS.',
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 40.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02 * 40,
              color: AppColors.text1,
              height: 1.0,
            ),
          ),
          Gap(12.h),
          Text(
            'Connect with builders and trades. Apply for work, post jobs, and build your reputation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text2,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 1: Role Selection ─────────────────────────────────────────────────────

class _RolePage extends StatelessWidget {
  const _RolePage({
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final UserRole? selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Gap(24.h),
          Text(
            'YOUR ROLE',
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.12 * 11,
              color: AppColors.text3,
            ),
          ),
          Gap(8.h),
          Text(
            'What describes you best?',
            style: GoogleFonts.barlowCondensed(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02 * 28,
              color: AppColors.text1,
            ),
          ),
          Gap(8.h),
          Text(
            'Choose your role to personalise your experience.',
            style: GoogleFonts.barlow(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text2,
            ),
          ),
          Gap(24.h),
          _RoleCard(
            role: UserRole.builder,
            selected: selectedRole == UserRole.builder,
            onTap: () => onRoleChanged(UserRole.builder),
          ),
          Gap(12.h),
          _RoleCard(
            role: UserRole.trade,
            selected: selectedRole == UserRole.trade,
            onTap: () => onRoleChanged(UserRole.trade),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
      decoration: BoxDecoration(
        color: selected ? AppColors.foundation : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: selected ? AppColors.foundation : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: selected ? AppColors.action : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  role == UserRole.builder
                      ? Iconsax.briefcase
                      : Iconsax.personalcard,
                  size: 22.r,
                  color: selected ? Colors.white : AppColors.text2,
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: GoogleFonts.barlow(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.text1,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      role.description,
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
              if (selected)
                Icon(Iconsax.tick_circle, size: 20.r, color: Colors.white)
              else
                Container(
                  width: 20.r,
                  height: 20.r,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.badge.r),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 2: Profile Setup ──────────────────────────────────────────────────────

class _ProfileSetupPage extends StatelessWidget {
  const _ProfileSetupPage({
    required this.role,
    required this.locationController,
    required this.companyNameController,
    required this.selectedBusinessType,
    required this.selectedTradeCategory,
    required this.selectedYearsExp,
    required this.onBusinessTypeChanged,
    required this.onTradeCategoryChanged,
    required this.onYearsExpChanged,
  });

  final UserRole? role;
  final TextEditingController locationController;
  final TextEditingController companyNameController;
  final String? selectedBusinessType;
  final String? selectedTradeCategory;
  final String? selectedYearsExp;
  final ValueChanged<String?> onBusinessTypeChanged;
  final ValueChanged<String?> onTradeCategoryChanged;
  final ValueChanged<String?> onYearsExpChanged;

  @override
  Widget build(BuildContext context) {
    if (role == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role == UserRole.builder ? 'COMPANY SETUP' : 'YOUR TRADE',
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.12 * 11,
              color: AppColors.text3,
            ),
          ),
          Gap(8.h),
          Text(
            role == UserRole.builder
                ? 'Tell us about your business.'
                : 'Tell us about your skills.',
            style: GoogleFonts.barlowCondensed(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02 * 28,
              color: AppColors.text1,
            ),
          ),
          Gap(8.h),
          Text(
            'You can update this anytime from your profile.',
            style: GoogleFonts.barlow(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text3,
            ),
          ),
          Gap(24.h),
          if (role == UserRole.builder)
            _BuilderForm(
              companyNameController: companyNameController,
              locationController: locationController,
              selectedBusinessType: selectedBusinessType,
              onBusinessTypeChanged: onBusinessTypeChanged,
            )
          else
            _TradeForm(
              locationController: locationController,
              selectedTradeCategory: selectedTradeCategory,
              selectedYearsExp: selectedYearsExp,
              onTradeCategoryChanged: onTradeCategoryChanged,
              onYearsExpChanged: onYearsExpChanged,
            ),
          Gap(24.h),
        ],
      ),
    );
  }
}

class _BuilderForm extends StatelessWidget {
  const _BuilderForm({
    required this.companyNameController,
    required this.locationController,
    required this.selectedBusinessType,
    required this.onBusinessTypeChanged,
  });

  final TextEditingController companyNameController;
  final TextEditingController locationController;
  final String? selectedBusinessType;
  final ValueChanged<String?> onBusinessTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: companyNameController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.barlow(fontSize: 15.sp, color: AppColors.text1),
          decoration: InputDecoration(
            labelText: 'Company name',
            prefixIcon: Icon(Iconsax.building, size: 20.r),
          ),
        ),
        Gap(20.h),
        Text(
          'Business type',
          style: GoogleFonts.barlow(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.text2,
          ),
        ),
        Gap(8.h),
        _ChipGroup(
          options: const ['Sole trader', 'Company', 'Partnership'],
          selected: selectedBusinessType,
          onSelected: onBusinessTypeChanged,
        ),
        Gap(20.h),
        TextField(
          controller: locationController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.barlow(fontSize: 15.sp, color: AppColors.text1),
          decoration: InputDecoration(
            labelText: 'City or suburb',
            prefixIcon: Icon(Iconsax.location, size: 20.r),
          ),
        ),
      ],
    );
  }
}

class _TradeForm extends StatelessWidget {
  const _TradeForm({
    required this.locationController,
    required this.selectedTradeCategory,
    required this.selectedYearsExp,
    required this.onTradeCategoryChanged,
    required this.onYearsExpChanged,
  });

  final TextEditingController locationController;
  final String? selectedTradeCategory;
  final String? selectedYearsExp;
  final ValueChanged<String?> onTradeCategoryChanged;
  final ValueChanged<String?> onYearsExpChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trade',
          style: GoogleFonts.barlow(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.text2,
          ),
        ),
        Gap(8.h),
        _ChipGroup(
          options: const [
            'Electrician',
            'Plumber',
            'Carpenter',
            'Plasterer',
            'Painter',
            'Concreter',
            'Welder',
            'Bricklayer',
            'Tiler',
            'Steel Fixer',
            'Form Worker',
            'Rigger',
            'Scaffolder',
            'Crane Operator',
            'Boilermaker',
            'Roof Plumber',
            'Cabinet Maker',
            'Demolition',
            'Other',
          ],
          selected: selectedTradeCategory,
          onSelected: onTradeCategoryChanged,
        ),
        Gap(20.h),
        Text(
          'Experience',
          style: GoogleFonts.barlow(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.text2,
          ),
        ),
        Gap(8.h),
        _ChipGroup(
          options: const ['<1 yr', '1–3 yrs', '3–5 yrs', '5+ yrs'],
          selected: selectedYearsExp,
          onSelected: onYearsExpChanged,
        ),
        Gap(20.h),
        TextField(
          controller: locationController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.barlow(fontSize: 15.sp, color: AppColors.text1),
          decoration: InputDecoration(
            labelText: 'City or suburb',
            prefixIcon: Icon(Iconsax.location, size: 20.r),
          ),
        ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: options.map((option) {
        final isSelected = selected == option;
        return GestureDetector(
          onTap: () => onSelected(isSelected ? null : option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.ease,
            height: 32.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.foundation : AppColors.surface,
              border: Border.all(
                color: isSelected ? AppColors.foundation : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(AppRadius.chip.r),
            ),
            child: Text(
              option,
              style: GoogleFonts.barlow(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Page 3: All Set ────────────────────────────────────────────────────────────

class _AllSetPage extends StatelessWidget {
  const _AllSetPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'lib/core/assets/mark-jobdun.svg',
            width: 64.r,
            height: 64.r,
          ),
          Gap(32.h),
          Text(
            "YOU'RE ALL SET.",
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 40.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02 * 40,
              color: AppColors.text1,
              height: 1.0,
            ),
          ),
          Gap(12.h),
          Text(
            "Your profile is ready. Let's find your next opportunity.",
            textAlign: TextAlign.center,
            style: GoogleFonts.barlow(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text2,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.selectedRole,
    required this.isLoading,
    required this.pageController,
    required this.onNext,
    required this.onFinish,
  });

  final int currentPage;
  final int totalPages;
  final UserRole? selectedRole;
  final bool isLoading;
  final PageController pageController;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == totalPages - 1;
    final isRolePage = currentPage == 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
      child: Column(
        children: [
          SmoothPageIndicator(
            controller: pageController,
            count: totalPages,
            effect: ExpandingDotsEffect(
              dotColor: AppColors.border,
              activeDotColor: AppColors.foundation,
              dotHeight: 6.r,
              dotWidth: 6.r,
              expansionFactor: 3,
            ),
          ),
          Gap(20.h),
          if (isLastPage)
            AppButton(
              label: isLoading ? 'Setting up...' : 'Go to dashboard',
              isLoading: isLoading,
              onPressed: isLoading ? null : onFinish,
            )
          else
            AppButton(
              label: currentPage == 2 ? 'Continue' : 'Next',
              variant: (isRolePage && selectedRole == null)
                  ? AppButtonVariant.ghost
                  : AppButtonVariant.primary,
              onPressed:
                  (isRolePage && selectedRole == null) ? null : onNext,
            ),
        ],
      ),
    );
  }
}
