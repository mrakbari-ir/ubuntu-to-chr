<div dir="rtl">

# CHR Installer

اسکریپت نصب MikroTik CHR روی سرور یا VPS، از طریق rescue mode.

نویسنده: mrakbari_ir
گیت‌هاب: https://github.com/mrakbari_ir

## کاربرد

وقتی سرور فقط دسترسی rescue/Linux داره (نه netboot مستقیم CHR)، این اسکریپت این کارها رو انجام می‌ده:

- ایمیج CHR رو دانلود و اکسترکت می‌کنه
- تنظیمات شبکه (IP و Gateway) رو از خود سیستم rescue می‌گیره و داخل autorun.scr می‌ذاره
- پسورد ست می‌کنه
- دیسک ایمیج رو resize می‌کنه
- مستقیم روی دیسک اصلی سرور می‌نویسه
- سرور رو ری‌استارت می‌کنه

بعد از بوت، CHR با IP و پسورد از پیش تنظیم‌شده بالا میاد، بدون نیاز به کنسول یا VNC.

## قبل از اجرا

- حتماً با دستور lsblk چک کن دیسک اصلی سرور اسمش چیه، بعد متغیر TARGET_DISK رو داخل اسکریپت درست کن. پیش‌فرض روی /dev/vda هست.
- این اسکریپت دیسک مقصد رو کامل پاک می‌کنه، برگشت نداره.
- روی محیط rescue لینوکس (Debian یا Ubuntu) و با دسترسی root اجرا کن.

## نصب

</div>

```bash
curl -O https://raw.githubusercontent.com/mrakbari-ir/ubuntu-to-chr/main/install.sh
chmod +x install.sh
./install.sh
```

<div dir="rtl">

یا مستقیم با یک خط، بدون دانلود جدا:

</div>

```bash
bash <(curl -s https://raw.githubusercontent.com/mrakbari-ir/ubuntu-to-chr/main/install.sh)
```

<div dir="rtl">

سورس کامل اسکریپت:
https://github.com/mrakbari-ir/ubuntu-to-chr/blob/main/install.sh

## اجرا

</div>

```bash
chmod +x chr-install.sh
./chr-install.sh
```

<div dir="rtl">

موقع اجرا، اسکریپت مقدار TARGET_DISK رو نشون می‌ده و ازت می‌خواد کلمه YES رو تایپ کنی تا ادامه بده.

## تنظیمات قابل تغییر

این متغیرها بالای اسکریپت هستن:

- CHR_VERSION: ورژن RouterOS CHR، پیش‌فرض 7.19.4
- TARGET_DISK: دیسکی که کامل پاک و overwrite میشه، پیش‌فرض /dev/vda
- NEW_SIZE_BYTES: سایز دیسک مجازی بعد از resize، پیش‌فرض 1073741824 (یک گیگابایت)
- PASSWORD: پسورد یوزر root روی CHR، اگه ست نکنی رندوم تولید میشه

برای ست کردن پسورد دستی:

</div>

```bash
PASSWORD=yourpass ./chr-install.sh
```

<div dir="rtl">

## بعد از نصب

- یوزرنیم: root
- پسورد: همونی که موقع اجرا توی خروجی چاپ میشه، یا همون PASSWORD که خودت دادی
- تلنت غیرفعاله، DNS روی 1.1.1.1 و 1.0.0.1 ست شده

## نکات

- اگه دانلود از download.mikrotik.com به مشکل فیلترینگ خورد، از یه مسیر یا mirror دیگه استفاده کن.
- اگه دیسک سرور /dev/sda هست نه /dev/vda (رایج توی بعضی VPS ها)، حتماً TARGET_DISK رو عوض کن.

</div>
