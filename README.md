<div align="center">

# 4X-UI

**فورک 3X-UI با ضریب مصرف + ادمین محدود**

[English](#english) | [فارسی](#فارسی)

</div>

---

## English

**4X-UI** is a fork of [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) — kept
in sync with upstream, extended with two features upstream does not have:

1. **Per-inbound usage multiplier** — count a client's traffic as more (or less)
   than what Xray actually reports.
2. **Limited admin role** — a second account type that manages inbounds and
   clients only.

Everything else is stock 3x-ui: multi-protocol inbounds, REALITY, multi-node,
subscription server, Telegram/Discord bots, PostgreSQL, the works.

### Why

Upstream 3x-ui is actively maintained but has neither feature. The Heimdall fork
has both but stopped tracking upstream. 4X-UI takes the latest 3x-ui and ports
just those two features forward.

### Usage multiplier

Each inbound gets a multiplier in its form. Traffic for clients on that inbound is
written multiplied.

| Multiplier | Effect                                |
| ---------- | ------------------------------------- |
| `0` / `1`  | actual usage (default)                |
| `2`        | counts double — quota burns 2× faster |
| `0.5`      | counts half                           |

- Per **inbound**; applies to every client on it.
- A client shared across inbounds is scaled per inbound.
- `0` and negatives fall back to `1`, so a mistyped field never zeroes traffic.
- If scaling fails, the **raw** traffic is written and a warning is logged —
  billing never silently stops.

### Admin roles

| Role      | Can do                              |
| --------- | ----------------------------------- |
| `admin`   | Everything (stock 3x-ui behaviour). |
| `limited` | Inbounds and clients only.          |

A limited admin **cannot** reach: panel settings, Xray configuration, server
control (start/stop/restart Xray, panel update, logs, DB import), backup, API
tokens, node management, subscription balancers, or the admin accounts page.

Enforcement is on the **backend** — `middleware.AdminOnly()` returns `403` on the
protected route groups, not just hidden menu entries. The frontend additionally
hides the Settings, Xray and API-docs tabs.

The **first account (id 1) is the owner**: always full control, cannot be deleted
or disabled, even on an upgraded database that predates the `role` column.

Manage accounts under **Settings → Panel admins**: create (role defaults to
**limited**), enable/disable, delete.

### Compatibility

- Automatic migration on first start: existing inbounds get multiplier `1`,
  existing accounts become enabled full admins.
- The stock single-admin setup behaves exactly as before; new endpoints are
  additive.

### Install

The one-line installer and the updater still point at the upstream 3x-ui release
assets, so for now clone and build:

```bash
git clone https://github.com/Mahdips/4x-ui.git
cd 4x-ui
# frontend
cd frontend && npm install && npm run build && cd ..
# backend (needs CGO for sqlite)
go build -o x-ui main.go
```

Then follow the upstream [3x-ui docs](https://docs.sanaei.dev) for the systemd
setup, database options, environment variables, multi-node, and Docker.

### License

GPL-3.0, inherited from 3x-ui.

---

## فارسی

**4X-UI** یک فورک از [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) است که
با آپاستریم هماهنگ نگه داشته می‌شود و دو قابلیتی که آپاستریم ندارد را اضافه می‌کند:

۱. **ضریب مصرف برای هر اینباند** — ترافیک کلاینت‌ها بیشتر (یا کمتر) از مقدار واقعی
گزارش‌شده توسط Xray حساب شود.
۲. **نقش ادمین محدود** — نوع حسابی که فقط اینباند و کلاینت‌ها را مدیریت می‌کند.

بقیه چیزها دقیقاً همان 3x-ui است: اینباند چندپروتکلی، REALITY، چندنوده، سرور
سابسکریپشن، بات تلگرام/دیسکورد، پشتیبانی PostgreSQL و غیره.

### چرا

آپاستریم 3x-ui به‌طور فعال توسعه داده می‌شود ولی هیچ‌کدام از این دو قابلیت را ندارد.
فورک Heimdall هر دو را دارد اما از آپاستریم عقب مانده است. 4X-UI آخرین نسخه 3x-ui را
می‌گیرد و فقط همان دو قابلیت را به جلو می‌آورد.

### ضریب مصرف

هر اینباند در فرم خودش یک ضریب می‌گیرد. ترافیک کلاینت‌های آن اینباند ضریب‌دار نوشته
می‌شود.

| ضریب      | اثر                                                      |
| --------- | -------------------------------------------------------- |
| `۰` / `۱` | مصرف واقعی (پیش‌فرض)                                     |
| `۲`       | دو برابر حساب می‌شود — حجم دو برابر سریع‌تر تمام می‌شود    |
| `۰.۵`     | نصف حساب می‌شود                                          |

- ضریب **روی اینباند** تعریف می‌شود و روی همه کلاینت‌هایش اعمال می‌گردد.
- کلاینتی که روی چند اینباند مشترک است، به ازای هر اینباند جدا ضریب می‌خورد.
- `۰` و مقادیر منفی به `۱` تبدیل می‌شوند، پس اشتباه تایپی هرگز ترافیک را صفر نمی‌کند.
- اگر اعمال ضریب خطا بدهد، ترافیک **خام** نوشته می‌شود و یک هشدار لاگ می‌خورد —
  شارژ کاربران هرگز بی‌صدا متوقف نمی‌شود.

### نقش‌های ادمین

| نقش       | دسترسی                                                    |
| --------- | --------------------------------------------------------- |
| `admin`   | همه چیز (رفتار معمول 3x-ui).                              |
| `limited` | فقط اینباند و کلاینت‌ها.                                  |

ادمین محدود **نمی‌تواند** به این موارد برسد: تنظیمات پنل، کانفیگ Xray، کنترل سرور
(استارت/استاپ/ری‌استارت Xray، آپدیت پنل، لاگ‌ها، ایمپورت دیتابیس)، بکاپ، توکن‌های API،
مدیریت نودها، بالانسرهای سابسکریپشن، و صفحه حساب‌های ادمین.

اعمال محدودیت روی **بک‌اند** است — `middleware.AdminOnly()` روی گروه مسیرهای
محافظت‌شده `۴۰۳` برمی‌گرداند، نه فقط مخفی کردن منو. فرانت‌اند هم تب‌های تنظیمات، Xray
و مستندات API را مخفی می‌کند.

**اولین حساب (id 1) مالک است**: همیشه دسترسی کامل، قابل حذف یا غیرفعال کردن نیست، حتی
روی دیتابیس قدیمی‌ای که ستون `role` را ندارد.

مدیریت حساب‌ها از **تنظیمات → مدیران پنل**: ساخت (نقش پیش‌فرض **محدود**)، فعال/غیرفعال
کردن، حذف.

### سازگاری

- مایگریشن در اولین اجرا خودکار است: اینباند‌های موجود ضریب `۱` می‌گیرند و حساب‌های
  موجود همه ادمین کامل و فعال می‌شوند.
- ستاپ‌های تک‌ادمینیِ معمولی دقیقاً مثل قبل رفتار می‌کنند؛ endpointهای جدید additive
  هستند.

### نصب

اسکریپت نصب و آپدیت هنوز به releaseهای خود 3x-ui اشاره می‌کنند، فعلاً کلون و بیلد کنید:

```bash
git clone https://github.com/Mahdips/4x-ui.git
cd 4x-ui
# فرانت‌اند
cd frontend && npm install && npm run build && cd ..
# بک‌اند (برای sqlite به CGO نیاز است)
go build -o x-ui main.go
```

برای بقیه چیزها (ستاپ systemd، تنظیمات دیتابیس، متغیرهای محیطی، چندنوده، داکر) به
[مستندات 3x-ui](https://docs.sanaei.dev) مراجعه کنید.

### لایسنس

GPL-3.0، به ارث برده از 3x-ui.
