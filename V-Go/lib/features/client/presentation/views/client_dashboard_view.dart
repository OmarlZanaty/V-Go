import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../driver/presentation/widgets/current_trip_item.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_extension.dart';

class ClientDashboardView extends StatelessWidget {
  const ClientDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    verticalSpace(20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SlideInRight(
                          from: 200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مرحبا بك',
                                style: AppStyle.styleMedium14.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                              verticalSpace(2),
                              Text(
                                'عميلنا العزيز في V-Go',
                                style: AppStyle.styleMedium16.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SlideInLeft(
                          from: 200,
                          child: InkWell(
                            onTap: () {
                              context.pushNamed(Routes.notificationViewRoute);
                            },
                            borderRadius: const BorderRadius.all(
                              Radius.circular(50),
                            ),
                            child: const CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.darkGrey,
                              foregroundColor: AppColors.white,
                              child: Icon(
                                size: 26,
                                HugeIcons.strokeRoundedNotification03,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    verticalSpace(20),
                    BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
                      buildWhen: (p, c) {
                        return (c.currentTrip != p.currentTrip) ||
                            c.status.isCurrentTripReceived ||
                            c.status.isTripCanceledReceived;
                      },
                      builder: (context, state) {
                        if (state.currentTrip != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: CurrentTripItem(
                              currentTrip: state.currentTrip!,
                            ),
                          );
                        }
                        return const CaroselView();
                      },
                    ),
                    verticalSpace(25),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'في ',
                            style: AppStyle.styleMedium14.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          TextSpan(
                            text: 'V-Go',
                            style: AppStyle.styleMedium18.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' هتلاقي',
                            style: AppStyle.styleMedium14.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    verticalSpace(10),
                    Row(
                      children: [
                        Expanded(
                          child: SlideInRight(
                            from: 400,
                            delay: const Duration(milliseconds: 150),
                            child: _dashboardItem(
                              title: 'ارخص\nسعر',
                              image: 'assets/images/tag.png',
                            ),
                          ),
                        ),
                        horizontalSpace(8),
                        Expanded(
                          child: SlideInRight(
                            from: 400,
                            child: _dashboardItem(
                              title: 'توفير\nالوقت',
                              image: 'assets/images/time.png',
                            ),
                          ),
                        ),
                        horizontalSpace(8),
                        Expanded(
                          child: SlideInLeft(
                            from: 400,
                            child: _dashboardItem(
                              title: 'رحلة\nممتعة',
                              image: 'assets/images/good-choice.png',
                            ),
                          ),
                        ),
                        horizontalSpace(8),
                        Expanded(
                          child: SlideInLeft(
                            from: 400,
                            delay: const Duration(milliseconds: 150),
                            child: _dashboardItem(
                              title: 'تجربة\nفريدة',
                              image: 'assets/images/stars.png',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(child: verticalSpace(40)),
                    SlideInUp(
                      from: 400,
                      child: InkWell(
                        onTap: () async {
                          await context.pushNamed(Routes.clientMapViewRoute);
                        },
                        borderRadius: const BorderRadius.all(
                          Radius.circular(40),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.all(Radius.circular(40)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'اطلب سكوتر الان',
                                  style: AppStyle.styleMedium16.copyWith(
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              ShakeX(
                                infinite: true,
                                from: 10,
                                duration: const Duration(seconds: 6),
                                child: CircleAvatar(
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.3,
                                  ),
                                  radius: 20,
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    verticalSpace(16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Container _dashboardItem({required String title, required String image}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Image.asset(image, width: 45),
          ),
          verticalSpace(18),
          Text(
            title,
            style: AppStyle.styleMedium12.copyWith(
              color: AppColors.white,
              fontSize: 13.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class CaroselView extends StatefulWidget {
  const CaroselView({super.key});

  @override
  State<CaroselView> createState() => _CaroselViewState();
}

class _CaroselViewState extends State<CaroselView> {
  final List<String> images = [
    'assets/images/b6.jpg',
    'assets/images/b7.jpg',
    'assets/images/b3.jpg',
    'assets/images/b4.jpg',
  ];
  int _currentIndex = 0;
  late final PageController _pageController;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final int n = images.length;
        if (n > 1) {
          final int period = 2 * (n - 1);
          final int tick = (timer.tick - 1) % period;
          final int nextPage = tick <= (n - 1) ? tick : 2 * (n - 1) - tick;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          if (!mounted) return;
          setState(() {
            _currentIndex = nextPage;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(images[index], fit: BoxFit.fill),
              );
            },
          ),
        ),
        verticalSpace(14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
                setState(() {
                  _currentIndex = index;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == index ? 28 : 18,
                height: _currentIndex == index ? 4 : 3,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? AppColors.primary
                      : Colors.white30,
                  borderRadius: const BorderRadius.all(Radius.circular(50)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
