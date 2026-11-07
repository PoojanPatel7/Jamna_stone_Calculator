import 'pwa_install_stub.dart'
    if (dart.library.html) 'pwa_install_web.dart';

bool isPwaStandalone() => isPwaStandaloneImpl();

Future<bool> triggerPwaInstall() => triggerPwaInstallImpl();
