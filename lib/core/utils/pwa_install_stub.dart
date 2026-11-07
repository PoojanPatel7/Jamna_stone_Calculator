bool isPwaStandaloneImpl() => true; // Always considered standalone on native apps

Future<bool> triggerPwaInstallImpl() async => false;
