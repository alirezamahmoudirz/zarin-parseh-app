# زرین‌پارسه

اپلیکیشن Flutter فارسی برای:

- نمایش قیمت اونس جهانی طلا
- نمایش قیمت طلای ۱۸ و ۲۴ عیار
- اتصال به API دلخواه با مسیرهای JSON قابل تنظیم
- ذخیره آخرین قیمت موفق روی دستگاه
- به‌روزرسانی دوره‌ای قیمت‌ها
- محاسبه تقریبی ارزش طلا با اجرت، سود و مالیات ورودی کاربر

## پیش‌نیاز

- Flutter 3.x
- Dart 3.x
- Android Studio یا Android SDK

## اجرا

```bash
flutter pub get
flutter run
```

## ساخت APK

```bash
flutter build apk --release
```

فایل خروجی:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## ساخت APK برای معماری‌های مختلف

```bash
flutter build apk --split-per-abi --release
```

## API

از داخل برنامه وارد بخش «تنظیم API» شوید.

نمونه پاسخ:

```json
{
  "data": {
    "XAUUSD": 2650.5,
    "gold18": 45000000,
    "gold24": 60000000
  }
}
```

در این نمونه مسیرها:

```text
data.XAUUSD
data.gold18
data.gold24
```

هستند.

اگر API قیمت‌های ایران را به ریال برمی‌گرداند، گزینه «مقادیر ایران به ریال هستند» را فعال کنید تا برای نمایش به تومان تقسیم بر ۱۰ انجام شود.

## نکته امنیتی

کلید API را داخل سورس کد، GitHub یا فایل‌های commit شده قرار ندهید. در این نسخه هدر دلخواه فقط از داخل تنظیمات دستگاه وارد می‌شود.

## انتشار در GitHub

```bash
git init
git add .
git commit -m "Initial release"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/zarin-parseh.git
git push -u origin main
```

بعد از push، GitHub Actions می‌تواند APK را به‌صورت خودکار بسازد.

## مجوز

این پروژه برای استفاده شخصی/تجاری شما آماده شده است. قبل از انتشار عمومی، نام تجاری، API و شرایط سرویس قیمت را بررسی کنید.
