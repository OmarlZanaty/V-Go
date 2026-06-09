import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

/// Terms & Privacy. The wording below is placeholder boilerplate — replace the
/// section texts with your finalized legal copy (or point this screen at a
/// hosted policy URL) before publishing.
class TermsView extends StatelessWidget {
  const TermsView({super.key});

  static const List<(String, String)> _sections = [
    (
      'مقدمة',
      'باستخدامك تطبيق V-Go Captain فإنك توافق على الشروط والأحكام وسياسة '
          'الخصوصية الموضحة أدناه. يرجى قراءتها بعناية قبل استخدام الخدمة.'
    ),
    (
      'استخدام الخدمة',
      'يلتزم الكابتن بتقديم خدمة النقل وفقًا للقوانين المرورية المعمول بها، '
          'والحفاظ على سلامة الركاب، والالتزام بالأسعار والمسارات المتفق عليها '
          'عبر التطبيق.'
    ),
    (
      'الحساب والمسؤولية',
      'أنت مسؤول عن الحفاظ على سرية بيانات حسابك، وعن جميع الأنشطة التي تتم '
          'من خلاله. يجب أن تكون البيانات والمستندات المقدَّمة صحيحة وسارية.'
    ),
    (
      'الموقع الجغرافي',
      'يستخدم التطبيق موقعك الجغرافي أثناء العمل لمطابقتك مع الرحلات القريبة '
          'وتتبع الرحلة. يتم استخدام الموقع فقط لأغراض تشغيل الخدمة.'
    ),
    (
      'الخصوصية والبيانات',
      'نقوم بجمع البيانات اللازمة لتشغيل الخدمة (مثل الاسم ورقم الهاتف وبيانات '
          'المركبة والموقع). لا تتم مشاركة بياناتك مع أطراف ثالثة إلا بالقدر '
          'اللازم لتقديم الخدمة أو وفقًا لما يقتضيه القانون.'
    ),
    (
      'المدفوعات',
      'تُحتسب قيمة الرحلات وفقًا للتسعير المعتمد داخل التطبيق. تخضع أي خصومات '
          'أو عمولات للشروط المتفق عليها بينك وبين الشركة.'
    ),
    (
      'إنهاء الخدمة',
      'يحق للشركة تعليق أو إنهاء الحساب في حال مخالفة هذه الشروط أو إساءة '
          'استخدام الخدمة.'
    ),
    (
      'التواصل',
      'لأي استفسار بخصوص الشروط أو الخصوصية، يمكنك التواصل معنا عبر شاشة الدعم '
          'الفني داخل التطبيق.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الشروط والخصوصية',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(20.w),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => SizedBox(height: 18.h),
        itemBuilder: (_, i) {
          final (title, body) = _sections[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(child: Text(title, style: AppStyle.body)),
                ],
              ),
              SizedBox(height: 8.h),
              Text(body,
                  style: AppStyle.hint.copyWith(height: 1.7),
                  textAlign: TextAlign.justify),
            ],
          );
        },
      ),
    );
  }
}
