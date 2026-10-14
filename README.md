<div align="center">

# 4X-UI

**فورک ۳X-UI با ضریب مصرف + ادمین محدود**

[English](#english) · [فارسی](#فارسی)

</div>

---

## English

A fork of [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui), kept in sync with
upstream, adding the two features upstream does not have:

1. **Per-inbound usage multiplier** — bill a client more (or less) traffic than
   Xray actually reports.
2. **Limited admin role** — a sign-in account that can only manage inbounds and
   clients.

### Usage multiplier

Each inbound carries a multiplier, set in the inbound form:

| Value     | Effect                                                   |
| --------- | -------------------------------------------------------- |
| `0` / `1` | real usage (default)                                     |
| `2`       | every byte counts as two — quota drains twice as fast    |
| `0.5`     | every byte counts as half                                |

Applies per inbound, to every client on it. A client shared across multiple
inbounds is scaled per inbound. Values `<= 0` behave as `1`, so a bad field
never zeroes someone's traffic. If the scaling step fails, the real traffic is
written instead and a warning is logged — accounting never silently stops.

### Admin roles

| Role      | Access                                                   |
| --------- | -------------------------------------------------------- |
| `admin`   | Everything, exactly like stock 3x-ui.                    |
| `limited` | Inbounds and clients only.                               |

A limited admin cannot open or call: panel settings, Xray configuration, server
control (Xray start/stop/restart, panel update, logs, DB import), backup, API
tokens, node management, subscription balancers, or the admin accounts page.

The restriction is enforced on the **backend**: `middleware.AdminOnly()` answers
`403` on those route groups. Hiding the menu is just extra polish on top.

The **first account (id 1) is the owner** — always full access, can never be
deleted or disabled, even on a database upgraded from before the `role` column
existed.

Manage accounts in **Settings → Panel admins**: create (defaults to limited),
enable/disable, delete.

### Install

One-line installer (builds the panel from source on the server):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Mahdips/4x-ui/main/install.sh)
```

It installs Go and Node where needed, clones the repo, builds the frontend and
backend, fetches Xray-core from the XTLS/Xray-core releases, wires up the systemd service
and fail2ban, and starts the panel. Re-running it upgrades an existing install
in place — the database and settings are left untouched.

Manual build:

```bash
git clone https://github.com/Mahdips/4x-ui.git
cd 4x-ui
cd frontend && npm install && npm run build && cd ..
CGO_ENABLED=1 go build -o x-ui main.go
```

Everything else (systemd unit, database options, env vars, multi-node, Docker)
matches upstream; see the [3x-ui docs](https://docs.sanaei.dev).

### License

GPL-3.0, inherited from 3x-ui.

---

## فارسی

فورکی از [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) که با آپاستریم
هماهنگ نگه داشته می‌شود و دو قابلیتی که آپاستریم ندارد را اضافه می‌کند:

۱. **ضریب مصرف برای هر اینباند** — ترافیک کلاینت بیشتر (یا کمتر) از مقدار واقعی
شمارش شود.
۲. **نقش ادمین محدود** — حسابی که فقط اینباند و کلاینت‌ها را مدیریت می‌کند.

### ضریب مصرف

هر اینباند در فرم خودش یک ضریب دارد:

| ضریب     | اثر                                                       |
| -------- | --------------------------------------------------------- |
| `۰` / `۱`| مصرف واقعی (پیش‌فرض)                                      |
| `۲`      | هر بایت دو تا حساب می‌شود — حجم دو برابر زودتر تمام می‌شود |
| `۰.۵`    | هر بایت نصف حساب می‌شود                                   |

ضریب روی اینباند تعریف می‌شود و شامل همه کلاینت‌هایش می‌گردد. کلاینتی که روی چند
اینباند مشترک است به ازای هر اینباند جدا محاسبه می‌شود. مقادیر کوچک‌تر یا مساوی صفر
مثل `۱` رفتار می‌کنند، پس اشتباه در فرم هرگز ترافیک کسی را صفر نمی‌کند. اگر اعمال
ضریب خطا بدهد، ترافیک واقعی نوشته می‌شود و یک هشدار لاگ می‌خورد — شمارش هرگز
بی‌صدا متوقف نمی‌شود.

### نقش‌های ادمین

| نقش      | دسترسی                                                    |
| -------- | --------------------------------------------------------- |
| `admin`  | همه چیز، دقیقاً مثل 3x-ui معمولی.                          |
| `limited`| فقط اینباند و کلاینت‌ها.                                   |

ادمین محدود نمی‌توانداین موارد را باز کند یا صدا بزند: تنظیمات پنل، کانفیگ Xray،
کنترل سرور (استارت/استاپ/ری‌استارت Xray، آپدیت پنل، لاگ‌ها، ایمپورت دیتابیس)، بکاپ،
توکن‌های API، مدیریت نودها، بالانسرهای سابسکریپشن و صفحه حساب‌های ادمین.

محدودیت روی **بک‌اند** اعمال می‌شود: `middleware.AdminOnly()` روی آن گروه مسیرها
`۴۰۳` برمی‌گرداند. مخفی کردن منو فقط یک لایع اضافه روی آن است.

**اولین حساب (id 1) مالک است** — همیشه دسترسی کامل، هرگز قابل حذف یا غیرفعال کردن
نیست، حتی روی دیتابیسی که از قبل از وجود ستون `role` آپگرید شده.

مدیریت حساب‌ها در **تنظیمات → مدیران پنل**: ساخت (پیش‌فرض محدود)، فعال/غیرفعال، حذف.

### نصب

نصب با یک دستور (پنل را روی سرور از سورس بیلد می‌کند):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Mahdips/4x-ui/main/install.sh)
```

این اسکریپت در صورت نیاز Go و Node را نصب می‌کند، ریپو را کلون می‌کند،
فرانت‌اند و بک‌اند را بیلد می‌کند، Xray-core را از ریلیزهای XTLS/Xray-core
می‌گیرد، سرویس systemd و fail2ban را تنظیم و پنل را استارت می‌کند. اجرای دوباره
آن نصب قبلی را آپدیت می‌کند — دیتابیس و تنظیمات دست‌نخورده باقی می‌مانند.

بیلد دستی:

```bash
git clone https://github.com/Mahdips/4x-ui.git
cd 4x-ui
cd frontend && npm install && npm run build && cd ..
CGO_ENABLED=1 go build -o x-ui main.go
```

بقیه چیزها (واحد systemd، گزینه‌های دیتابیس، متغیرهای محیطی، چندنوده، داکر) مثل
آپاستریم است؛ به [مستندات 3x-ui](https://docs.sanaei.dev) مراجعه کنید.

### لایسنس

GPL-3.0، به ارث رسیده از 3x-ui.
