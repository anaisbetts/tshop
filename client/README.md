# tShop client

Flutter app for Android handhelds. There is always a **web** target whose
job is to demo the app in a browser. It does not install anything; device
services are stubbed on web.

## Toolchain

From `client/`, use the FVM wrappers (pin is `.fvmrc`, currently 3.47.2):

```bash
./flutterw run -d chrome   # web demo
./flutterw run             # Android
./tool/verify              # format, analyze, test, build web
```

Never a global `flutter`. Debug Android id is `dev.anais.tshop.dev`;
release is `dev.anais.tshop`.
