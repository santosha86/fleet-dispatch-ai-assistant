// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مساعد إرسال PB الذكي';

  @override
  String get chatTitle => 'روبوت المحادثة PB';

  @override
  String get online => 'متصل';

  @override
  String get howCanIHelp => 'كيف يمكنني مساعدتك اليوم؟';

  @override
  String get askAbout => 'اسأل عن الإرسال والشحنات والمقاولين والمسارات';

  @override
  String get typeMessage => 'اكتب رسالتك...';

  @override
  String get clearChat => 'مسح المحادثة';

  @override
  String get send => 'إرسال';

  @override
  String get showTable => 'عرض الجدول';

  @override
  String get showChart => 'عرض الرسم البياني';

  @override
  String get downloadCsv => 'تحميل CSV';

  @override
  String get selectOption => 'يرجى اختيار خيار:';

  @override
  String get selectDataSource => 'يرجى اختيار مصدر البيانات:';

  @override
  String get planning => 'جاري التخطيط...';

  @override
  String get retrievingDocs => 'جاري استرجاع المستندات...';

  @override
  String get analyzing => 'جاري التحليل...';

  @override
  String get errorConnect =>
      'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.';

  @override
  String get errorServer => 'الخادم غير متاح مؤقتاً. يرجى المحاولة مرة أخرى.';

  @override
  String showingRows(int shown, int total) {
    return 'عرض $shown من $total صف';
  }

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get statistics => 'الإحصائيات';

  @override
  String get queriesProcessed => 'الاستعلامات المعالجة';

  @override
  String get userSatisfaction => 'رضا المستخدمين';

  @override
  String get avgResponseTime => 'متوسط وقت الاستجابة';

  @override
  String get back => 'رجوع';

  @override
  String get noMessages => 'لا توجد رسائل بعد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'موافق';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get security => 'الأمان';

  @override
  String get pinLock => 'قفل PIN';

  @override
  String get pinEnabled => 'مفعل';

  @override
  String get pinDisabled => 'معطل';

  @override
  String get biometricLogin => 'تسجيل الدخول البيومتري';

  @override
  String get biometricEnabled => 'بصمة الإصبع / التعرف على الوجه مفعل';

  @override
  String get changePin => 'تغيير PIN';

  @override
  String get enterPin => 'أدخل رقم PIN للمتابعة';

  @override
  String get createPin => 'إنشاء رقم PIN';

  @override
  String get pinHint => 'اختر رقم PIN مكون من 4-6 أرقام لتأمين التطبيق.';

  @override
  String get confirmPin => 'تأكيد PIN';

  @override
  String get setPin => 'تعيين PIN';

  @override
  String get pinTooShort => 'يجب أن يكون PIN 4 أرقام على الأقل.';

  @override
  String get pinMismatch => 'أرقام PIN غير متطابقة. يرجى المحاولة مرة أخرى.';

  @override
  String get incorrectPin => 'رقم PIN غير صحيح.';

  @override
  String attemptsRemaining(int count) {
    return '$count محاولات متبقية.';
  }

  @override
  String get accountLocked => 'الحساب مقفل. محاولات فاشلة كثيرة.';

  @override
  String get useBiometrics => 'استخدام البصمة';

  @override
  String get capabilities => 'القدرات';

  @override
  String get routeDistribution => 'توزيع المسارات';

  @override
  String get shareMessage => 'مشاركة الرسالة';

  @override
  String get shareChart => 'مشاركة الرسم البياني';

  @override
  String get voiceInput => 'الإدخال الصوتي';

  @override
  String get listening => 'جاري الاستماع...';

  @override
  String get speechNotAvailable => 'التعرف على الكلام غير متاح على هذا الجهاز.';

  @override
  String get cachedResponse => 'استجابة مخزنة مؤقتاً (غير متصل)';

  @override
  String get offlineMode => 'وضع عدم الاتصال';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signIn => 'دخول';

  @override
  String get invalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get logout => 'تسجيل الخروج';
}
