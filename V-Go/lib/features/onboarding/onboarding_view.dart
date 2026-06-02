import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/cache/cache_helper.dart';
import '../../core/helpers/extensions.dart';
import '../../core/helpers/spacing.dart';
import '../../core/routing/routes.dart';
import '../../core/theming/app_colors.dart';
import '../../core/theming/app_style.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/widgets/custom_button.dart';

class OnboraingView extends StatefulWidget {
  const OnboraingView({super.key});

  @override
  State<OnboraingView> createState() => _OnboraingViewState();
}

class _OnboraingViewState extends State<OnboraingView> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PageView(
          controller: _controller,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          children: const [OnboardPage1(), OnboardPage2()],
        ),
      ),
      bottomSheet: Container(
        color: Colors.black,
        height: 150,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // المؤشرات (النقاط)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 5,
                    width: _currentPage == index ? 30 : 14,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
              verticalSpace(25),
              CustomButton(
                text: _currentPage == 1 ? 'ابدأ الآن' : 'التالي',
                height: 52,
                onPressed: () {
                  if (_currentPage == 1) {
                    context.pushReplacementNamed(Routes.accountTypeViewRoute);
                    CacheHelper.setData(
                      key: AppConstants.showOnboardingBefore,
                      value: true,
                    );
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardPage1 extends StatelessWidget {
  const OnboardPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFDDE01F).withValues(alpha: 0.3),
                    const Color(0xFFDDE01F).withValues(alpha: 0.2),
                    const Color(0xFFDDE01F).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideInDown(
                from: 400,
                child: Container(
                  height: 320,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    image: const DecorationImage(
                      image: AssetImage("assets/images/on_borading_image.jpg"),
                      fit: BoxFit.cover,
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                        color: Color(0xFFDDE01F),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              verticalSpace(30),
              SlideInUp(
                from: 400,
                child: Text(
                  'تنقل سريع وآمن',
                  textAlign: TextAlign.center,
                  style: AppStyle.styleBold24.copyWith(color: AppColors.white),
                ),
              ),
              verticalSpace(20),
              SlideInUp(
                from: 600,
                child: Text(
                  'احجز رحلتك و صِل إلى وجهتك بسرعة وأمان مع سائقين محترفين على دراجات ذات كفاءة عالية.',
                  textAlign: TextAlign.center,
                  style: AppStyle.styleRegular14.copyWith(
                    color: AppColors.white,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardPage2 extends StatelessWidget {
  const OnboardPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Align(
            child: Padding(
              padding: const EdgeInsets.only(top: 200),
              child: Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFDDE01F).withValues(alpha: 0.3),
                      const Color(0xFFDDE01F).withValues(alpha: 0.2),
                      const Color(0xFFDDE01F).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideInLeft(
              from: 400,
              child: const OnBoradingItem(
                title: 'تتبع مباشر',
                description: 'تابع موقع السائق لحظة بلحظة على الخريطة',
                icon: HugeIcons.strokeRoundedLocation01,
              ),
            ),
            verticalSpace(12),
            SlideInLeft(
              from: 600,
              child: const OnBoradingItem(
                title: 'وصول سريع',
                description: 'احجز رحلتك و صل إلى وجهتك في أسرع وقت',
                icon: HugeIcons.strokeRoundedTimeQuarter02,
              ),
            ),
            verticalSpace(12),
            SlideInLeft(
              from: 800,
              child: const OnBoradingItem(
                title: 'آمن وموثوق',
                description: 'سائقون معتمدون ومدربون لضمان رحلة آمنة',
                icon: HugeIcons.strokeRoundedSecurityValidation,
              ),
            ),
            verticalSpace(25),
            SlideInUp(
              from: 400,
              child: Text(
                'رحلتك بين يديك',
                textAlign: TextAlign.center,
                style: AppStyle.styleBold24.copyWith(color: AppColors.white),
              ),
            ),
            verticalSpace(17),
            SlideInUp(
              from: 400,
              child: SizedBox(
                width: 287,
                child: Text(
                  'احجز رحلتك بضغطة زر واستمتع بتجربة تنقل مريحة وآمنة وموفرة.',
                  textAlign: TextAlign.center,
                  style: AppStyle.styleRegular14.copyWith(
                    color: AppColors.white,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class OnBoradingItem extends StatelessWidget {
  const OnBoradingItem({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, left: 18, right: 20, bottom: 16),
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1D23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  title,
                  style: AppStyle.styleMedium16.copyWith(color: Colors.white),
                ),
                Text(
                  description,
                  style: AppStyle.styleRegular14.copyWith(
                    color: AppColors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SlideInRight(
                  from: 1000,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFDDE01F),
                    child: HugeIcon(
                      icon: icon,
                      color: AppColors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
