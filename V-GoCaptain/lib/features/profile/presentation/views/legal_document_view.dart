import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

/// Privacy, pricing, refund and contact pages, drawn in the app's own colours
/// (they used to be plain black-on-white PDFs).
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({required this.document, super.key});

  final LegalDocument document;

  /// Maps the old PDF asset paths (still used by the routes) to a document.
  static LegalDocument fromAsset(String? assetPath) {
    final name = (assetPath ?? '').split('/').last;
    return switch (name) {
      'pricingPolicy.pdf' => LegalDocuments.pricing,
      'refundPolicy.pdf' => LegalDocuments.refund,
      'contactUs.pdf' => LegalDocuments.contact,
      _ => LegalDocuments.privacy,
    };
  }

  static TextStyle _font({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.white,
    double height = 1.7,
  }) => GoogleFonts.cairo(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(
          document.title,
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (document.intro != null) ...[
            _card(
              child: Text(
                document.intro!,
                style: _font(color: AppColors.white.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final section in document.sections) ...[
            _sectionCard(section),
            const SizedBox(height: 12),
          ],
          if (document.contacts.isNotEmpty)
            for (final contact in document.contacts) ...[
              _contactCard(contact),
              const SizedBox(height: 12),
            ],
          if (document.footer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                document.footer!,
                textAlign: TextAlign.center,
                style: _font(size: 12, color: AppColors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightWhite),
      ),
      child: child,
    );
  }

  Widget _sectionCard(LegalSection section) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: _font(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (section.body != null) ...[
            const SizedBox(height: 10),
            Text(section.body!, style: _font()),
          ],
          if (section.points.isNotEmpty) const SizedBox(height: 8),
          for (final point in section.points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(point, style: _font())),
                ],
              ),
            ),
          if (section.table.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final row in section.table)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1, style: _font())),
                    Text(
                      row.$2,
                      style: _font(
                        weight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _contactCard(LegalContact contact) {
    final card = _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(contact.icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.label,
                  style: _font(size: 12, color: AppColors.grey, height: 1.4),
                ),
                Text(
                  contact.value,
                  textDirection: contact.ltr ? TextDirection.ltr : null,
                  style: _font(
                    size: 15,
                    weight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (contact.uri != null)
            const Icon(Icons.chevron_left, color: AppColors.primary),
        ],
      ),
    );
    if (contact.uri == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => launchUrl(
        Uri.parse(contact.uri!),
        mode: LaunchMode.externalApplication,
      ),
      child: card,
    );
  }
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    this.intro,
    this.sections = const [],
    this.contacts = const [],
    this.footer,
  });

  final String title;
  final String? intro;
  final List<LegalSection> sections;
  final List<LegalContact> contacts;
  final String? footer;
}

class LegalSection {
  const LegalSection(
    this.title, {
    this.body,
    this.points = const [],
    this.table = const [],
  });

  final String title;
  final String? body;
  final List<String> points;
  final List<(String, String)> table;
}

class LegalContact {
  const LegalContact({
    required this.icon,
    required this.label,
    required this.value,
    this.uri,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? uri;
  final bool ltr;
}

abstract final class LegalDocuments {
  static const supportPhone = '01112333925';
  static const supportEmail = 'scooterzscooterz5@gmail.com';

  static const privacy = LegalDocument(
    title: 'سياسة الخصوصية',
    intro:
        'باستخدامك تطبيق V-Go فأنت توافق على الشروط التالية. نرجو قراءتها بعناية.',
    sections: [
      LegalSection(
        '1. نموذج العمل',
        points: [
          'تربط المنصة بين السائقين المستقلين والركاب فقط.',
          'الراكب يختار السائق من قائمة العروض.',
          'الدفع يكون عبر المنصة، والسعر يشمل كل الرسوم.',
          'الشركة لا تتدخل في الاتفاق بين السائق والراكب.',
        ],
      ),
      LegalSection(
        '2. الحساب',
        points: [
          'يجب أن يكون عمرك 18 سنة أو أكثر.',
          'يجب إدخال بيانات صحيحة وحديثة.',
          'قد يتم طلب مستندات للتحقق من الهوية حسب قوانين غسيل الأموال.',
          'يوجد حسابان: راكب وسائق، والسائق يحتاج تحقق إضافي.',
        ],
      ),
      LegalSection(
        '3. السلامة',
        points: [
          'تقوم المنصة بالتحقق من مستندات السائقين.',
          'قد تتم عمليات فحص عشوائية للتأكد من صحة استخدام الحساب.',
          'الشركة لا تتحكم في جودة الخدمة على أرض الواقع.',
          'يجب على المستخدمين توخي الحذر عند التعامل فيما بينهم.',
        ],
      ),
      LegalSection(
        '4. التزامات السائق',
        points: [
          'وجود رخصة قيادة سارية واللياقة الصحية.',
          'قيادة اسكوتر مُبلَّغ عنه وفي حالة جيدة.',
          'عدم طلب أي مبالغ إضافية خارج المنصة.',
          'الالتزام بالقوانين الضريبية.',
          'عدم التمييز أو التصرف بشكل خطير أو غير قانوني.',
          'عدم استخدام المعلومات خارج إطار تقديم الخدمة.',
        ],
      ),
      LegalSection(
        '5. التواصل',
        points: [
          'التواصل مع الركاب فقط لأغراض الرحلة.',
          'قطع الاتصال بعد انتهاء الرحلة إلا إذا كان لإرجاع شيء مفقود.',
          'يمكن مراقبة محادثات التطبيق لضمان الالتزام بالشروط.',
        ],
      ),
      LegalSection(
        '6. اتصالات V-Go',
        points: [
          'قد ترسل المنصة إشعارات ورسائل وتسويق.',
          'يمكن إلغاء الاشتراك من الرسائل التي تتطلب موافقة.',
        ],
      ),
      LegalSection(
        '7. ما يُمنع فعله على المنصة',
        points: [
          'أي نشاط غير قانوني أو مخالف للشروط.',
          'بيع أو نقل الحساب.',
          'انتحال الهوية.',
          'التحريض على أنشطة خطيرة.',
          'رفع محتوى مخالف أو منتهك للحقوق.',
          'محاولة اختراق المنصة أو استخراج البيانات.',
        ],
      ),
      LegalSection(
        '8. حقوق الشركة',
        points: [
          'يحق للشركة تعليق أو إغلاق الحساب عند مخالفة الشروط.',
          'يمكن اتخاذ إجراءات بناءً على خطورة المخالفة.',
        ],
      ),
      LegalSection(
        '9. المسؤولية',
        points: [
          'المنصة غير مسؤولة عن أي أضرار أو خسائر ناتجة عن استخدام الخدمة.',
          'لا تضمن جودة أو دقة أي خدمة مقدمة من السائقين.',
        ],
      ),
      LegalSection(
        '10. خدمات الطرف الثالث',
        points: [
          'المنصة ليست طرفاً في النزاعات بين المستخدمين.',
          'الروابط الخارجية ليست تحت مسؤولية الشركة.',
        ],
      ),
      LegalSection(
        '11. تسوية المنازعات',
        points: [
          'تخضع الشروط لقانون جمهورية مصر العربية.',
          'تُحل النزاعات عبر التحكيم وفق قواعد مركز فيينا (VIAC).',
        ],
      ),
      LegalSection(
        '12. التعديلات',
        points: [
          'يمكن تحديث الشروط في أي وقت، وسيتم إعلام المستخدم بالتغييرات المهمة.',
        ],
      ),
      LegalSection(
        '13. أحكام عامة',
        points: ['الخدمة تُقدَّم "كما هي".', 'يجب تحديث التطبيق باستمرار.'],
      ),
      LegalSection(
        '14. البضائع المحظورة',
        body: 'يشمل ذلك على سبيل المثال لا الحصر:',
        points: [
          'المخدرات – المواد السامة – المتفجرات.',
          'الأسلحة – العملات – المجوهرات الثمينة.',
          'البشر والحيوانات والمواد البيولوجية.',
          'المواد سريعة التلف أو القابلة للكسر.',
          'البضائع غير القانونية أو المسروقة.',
        ],
      ),
    ],
  );

  static const pricing = LegalDocument(
    title: 'سياسة التسعير',
    intro:
        'تعتمد منصتنا نظام تسعير شفاف يضمن حقوق العميل والسائق على حد سواء.',
    sections: [
      LegalSection(
        'طريقة حساب الأجرة',
        body:
            'الأجرة = المسافة الفعلية بالكيلومتر × سعر الكيلومتر، وتُقرَّب لأقرب جنيه. لا توجد أجرة فتح عداد ولا حد أدنى للأجرة.',
      ),
      LegalSection(
        'جدول الأسعار',
        table: [('دراجة نارية / سكوتر — سعر الكيلومتر', '5.50 ج.م')],
      ),
      LegalSection(
        'تغيير المسار',
        body:
            'في حال طلب العميل تغيير وجهة الوصول أثناء الرحلة، يُعاد حساب التكلفة بناءً على المسافة الفعلية الجديدة.',
      ),
      LegalSection(
        'ملاحظة',
        body:
            'قد تتغير الأسعار، وسيتم إخطار العميل بأي تحديث في التسعير عبر التطبيق قبل طلب الرحلة.',
      ),
    ],
  );

  static const refund = LegalDocument(
    title: 'سياسة الاسترجاع',
    intro:
        'نحن في V-Go نسعى لتقديم أفضل خدمة لعملائنا. في حال حدوث أي مشكلة تقنية أو خطأ في عملية الدفع، تخضع عمليات الاسترجاع للشروط التالية:',
    sections: [
      LegalSection(
        'حالات استحقاق الاسترداد',
        points: [
          'إذا تم سحب المبلغ من البطاقة ولم يتم تأكيد الرحلة في النظام.',
          'إذا قام السائق بإلغاء الرحلة بعد خصم القيمة (في حالات الدفع المسبق).',
          'إذا ثبت وجود خطأ تقني أدى لخصم مبلغ إضافي غير مستحق.',
        ],
      ),
      LegalSection(
        'رسوم الإلغاء',
        body:
            'قد يتم خصم رسوم إلغاء بسيطة من العميل في حال وصول السائق لموقع العميل وإلغاء الرحلة من طرف العميل بعد وقت السماح (5 دقائق).',
      ),
      LegalSection(
        'آلية الاسترداد',
        body:
            'يتم استرداد المبالغ إلى نفس الوسيلة المستخدمة في الدفع (البطاقة البنكية / المحفظة الإلكترونية).',
      ),
      LegalSection(
        'المدة الزمنية',
        body:
            'تستغرق عملية إعادة الأموال عادةً ما بين 5 إلى 14 يوم عمل، وذلك حسب سياسة البنك المصدر للبطاقة.',
      ),
      LegalSection(
        'النزاعات والشكاوى',
        body:
            'في حال وجود شكوى بشأن رحلة مكتملة، يجب التواصل مع الدعم وتقديم الشكوى في غضون 24 ساعة للمراجعة واتخاذ القرار المناسب. يمكنك التواصل مع الدعم عبر قسم "تواصل معنا".',
      ),
    ],
  );

  static const contact = LegalDocument(
    title: 'تواصل معنا',
    intro:
        'نحن هنا لمساعدتك! إذا كان لديك أي استفسار حول رحلاتك، أو واجهت مشكلة في الدفع أو مع السائقين أو أثناء استخدام التطبيق، يسعدنا تواصلك معنا عبر القنوات التالية:',
    contacts: [
      LegalContact(
        icon: Icons.phone_in_talk_rounded,
        label: 'رقم الهاتف',
        value: supportPhone,
        uri: 'tel:$supportPhone',
        ltr: true,
      ),
      LegalContact(
        icon: Icons.email_outlined,
        label: 'البريد الإلكتروني للدعم (الرد خلال 24 ساعة)',
        value: supportEmail,
        uri: 'mailto:$supportEmail',
        ltr: true,
      ),
      LegalContact(
        icon: Icons.support_agent_rounded,
        label: 'الدعم الفني عبر التطبيق',
        value: 'شات "خدمة العملاء" داخل التطبيق',
      ),
      LegalContact(
        icon: Icons.location_on_outlined,
        label: 'المقر الرئيسي',
        value: 'ش عمر بن الخطاب، السلام 1، فيصل، السويس، مصر',
      ),
      LegalContact(
        icon: Icons.schedule_rounded,
        label: 'ساعات العمل',
        value: 'من الأحد إلى الخميس، 9 صباحاً حتى 5 مساءً',
      ),
    ],
  );
}
