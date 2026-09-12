import 'dart:ui' show PlatformDispatcher;

/// A small hand-written bilingual string table (Indonesian / English) that
/// follows the device's system locale directly.
///
/// This deliberately isn't Flutter's official ARB+codegen localization
/// pipeline: that requires a `flutter gen-l10n` build step this environment
/// has no way to run or verify, so a single mismatched key would silently
/// break the whole app. Every string here is plain, greppable Dart the
/// compiler checks like anything else.
class AppStrings {
  AppStrings() : _id = PlatformDispatcher.instance.locale.languageCode == 'id';

  final bool _id;

  String _t(String id, String en) => _id ? id : en;

  // ---------------------------------------------------------------------
  // Common
  // ---------------------------------------------------------------------
  String get cancel => _t('Batal', 'Cancel');
  String get save => _t('Simpan', 'Save');
  String get delete => _t('Hapus', 'Delete');
  String get edit => 'Edit';
  String get rename => 'Rename';
  String get later => _t('Nanti', 'Later');
  String get open => _t('Buka', 'Open');
  String get tryAgain => _t('Coba lagi', 'Try again');
  String get requiredField => _t('Wajib diisi', 'Required');
  String get invalidPort => _t('Port tidak valid', 'Invalid port');
  String get confirmDeleteTitle => _t('Hapus?', 'Delete?');
  String deleteItemBody(String name) =>
      _t('"$name" akan dihapus.', '"$name" will be deleted.');

  // ---------------------------------------------------------------------
  // Host list (main screen)
  // ---------------------------------------------------------------------
  String updateAvailable(int build) =>
      _t('Update tersedia (build $build)', 'Update available (build $build)');
  String get activeSessions => _t('Sesi Aktif', 'Active Sessions');
  String activeSessionsCount(int count) =>
      _t('Sesi Aktif ($count)', 'Active Sessions ($count)');
  String get importFromComputer =>
      _t('Import dari Komputer', 'Import from Computer');
  String get manageGroups => _t('Kelola Grup', 'Manage Groups');
  String get commandShortcuts => _t('Command Shortcut', 'Command Shortcuts');
  String get webShortcuts => _t('Web Shortcut', 'Web Shortcuts');
  String get settings => _t('Pengaturan', 'Settings');
  String get account => _t('Akun', 'Account');
  String get signInAlterOne => 'Sign In Alter One';
  String get logout => 'Logout';
  String get sftp => 'SFTP';
  String get portForward => 'Port Forward';
  String get searchHint =>
      _t('Cari host, alamat, atau tag…', 'Search host, address, or tag…');
  String get deleteHostTitle => _t('Hapus host?', 'Delete host?');
  String deleteHostBody(String name) => _t(
    'Host "$name" akan dihapus.',
    'Host "$name" will be deleted.',
  );
  String loginSuccess(String name) =>
      _t('Berhasil login sebagai $name', 'Logged in as $name');
  String get logoutConfirmTitle => _t('Logout?', 'Log out?');
  String get noHostsYet => _t('Belum ada host SSH', 'No SSH hosts yet');
  String get addHost => _t('Tambah host', 'Add host');
  String get noMatchingHosts =>
      _t('Tidak ada host yang cocok', 'No hosts match');
  String get ungrouped => _t('Tanpa grup', 'Ungrouped');

  // ---------------------------------------------------------------------
  // Web Shortcuts
  // ---------------------------------------------------------------------
  String get webShortcutTitle => _t('Web Shortcut', 'Web Shortcuts');
  String get addShortcut => _t('Tambah Shortcut', 'Add Shortcut');
  String get editShortcut => _t('Edit Shortcut', 'Edit Shortcut');
  String get shortcutName => _t('Nama', 'Name');
  String get shortcutUrl => 'URL';
  String get favorites => _t('Favorit', 'Favorites');
  String get allShortcuts => _t('Semua', 'All');
  String get noShortcutsYet => _t('Belum ada shortcut', 'No shortcuts yet');
  String get addShortcutTooltip => _t('Tambah shortcut', 'Add shortcut');
  String get removeFromFavorites =>
      _t('Hapus dari favorit', 'Remove from favorites');
  String get addToFavorites => _t('Jadikan favorit', 'Add to favorites');
  String deleteShortcutBody(String name) => _t(
    'Shortcut "$name" akan dihapus.',
    'Shortcut "$name" will be deleted.',
  );

  // ---------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------
  String get settingsTitle => _t('Pengaturan', 'Settings');
  String get theme => _t('Tema', 'Theme');
  String get security => _t('Keamanan', 'Security');
  String get about => _t('Tentang', 'About');
  String get lockWithBiometrics =>
      _t('Kunci dengan biometrik', 'Lock with biometrics');
  String get lockWithBiometricsSubtitle => _t(
    'Minta sidik jari/PIN perangkat setiap kali membuka Termul, '
    'atau setelah 10 menit tidak disentuh',
    'Ask for your device fingerprint/PIN every time Termul opens, '
    'or after 10 minutes idle',
  );
  String get loadingVersion => _t('Memuat versi...', 'Loading version...');
  String versionLabel(String version, String build) =>
      _t('Versi $version ($build)', 'Version $version ($build)');
  String get checkForUpdates => _t('Cek Pembaruan', 'Check for Updates');
  String get updateCheckFailed => _t(
    'Tidak bisa mengecek pembaruan. Coba lagi nanti.',
    'Could not check for updates. Try again later.',
  );
  String upToDate(int build) =>
      _t('Sudah versi terbaru (build $build).', 'Already up to date (build $build).');
  String get updateAvailableTitle => _t('Update tersedia', 'Update available');
  String updateAvailableBody(int build) => _t(
    'Build $build sudah tersedia di GitHub.',
    'Build $build is available on GitHub.',
  );

  // ---------------------------------------------------------------------
  // SFTP
  // ---------------------------------------------------------------------
  String get newFolder => _t('Folder Baru', 'New Folder');
  String get folderName => _t('Nama folder', 'Folder name');
  String get newName => _t('Nama baru', 'New name');
  String failedToCreateFolder(Object error) =>
      _t('Gagal membuat folder: $error', 'Failed to create folder: $error');
  String failedToRename(Object error) =>
      _t('Gagal rename: $error', 'Failed to rename: $error');
  String deleteEntryBody(String name) =>
      _t('"$name" akan dihapus.', '"$name" will be deleted.');
  String failedToDelete(Object error) =>
      _t('Gagal menghapus: $error', 'Failed to delete: $error');
  String uploading(String name) => _t('Mengunggah $name', 'Uploading $name');
  String failedToUpload(Object error) =>
      _t('Gagal mengunggah: $error', 'Failed to upload: $error');
  String downloading(String name) => _t('Mengunduh $name', 'Downloading $name');
  String savedAt(String path) => _t('Tersimpan di $path', 'Saved to $path');
  String failedToDownload(Object error) =>
      _t('Gagal mengunduh: $error', 'Failed to download: $error');
  String get goUpFolder => _t('Naik satu folder', 'Go up one folder');
  String get newFolderTooltip => _t('Folder baru', 'New folder');
  String get upload => 'Upload';
  String get reload => _t('Muat ulang', 'Reload');
  String sftpConnectFailed(String error) =>
      _t('Gagal konek SFTP: $error', 'SFTP connection failed: $error');
  String get unknownError => _t('kesalahan tidak diketahui', 'unknown error');
  String get emptyFolder => _t('Folder kosong', 'Empty folder');
  String get download => 'Download';

  // ---------------------------------------------------------------------
  // Command Shortcuts
  // ---------------------------------------------------------------------
  String get runShortcut => _t('Jalankan Shortcut', 'Run Shortcut');
  String get commandLabel => 'Command';
  String get commandHint => _t('contoh: docker ps', 'e.g. docker ps');
  String get noCommandShortcutsYet =>
      _t('Belum ada shortcut', 'No shortcuts yet');
  String get deleteShortcutTitle =>
      _t('Hapus shortcut?', 'Delete shortcut?');

  // ---------------------------------------------------------------------
  // Terminal tabs
  // ---------------------------------------------------------------------
  String get terminalTitle => _t('Terminal', 'Terminal');
  String get allHostsHaveOpenSession => _t(
    'Semua host sudah punya sesi terbuka',
    'All hosts already have an open session',
  );
  String get noActiveSessions =>
      _t('Belum ada sesi terminal yang aktif', 'No active terminal sessions');
  String get backToHostList => _t('Kembali ke daftar host', 'Back to host list');
  String get newSession => _t('Sesi baru', 'New session');
  String get reconnect => _t('Sambungkan ulang', 'Reconnect');
  String connectFailed(String error) =>
      _t('Gagal konek: $error', 'Connection failed: $error');
  String get connectionLostReconnecting =>
      _t('Koneksi terputus - menyambungkan ulang…', 'Connection lost - reconnecting…');
  String get connectionLost => _t('Koneksi terputus', 'Connection lost');

  // ---------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------
  String get loginOptionalSubtitle => _t(
    'Login opsional — buat sync antar device nanti',
    'Login optional — for cross-device sync later',
  );
  String get loginWithAlterOne => 'Login with Alter One';

  // ---------------------------------------------------------------------
  // Lock screen
  // ---------------------------------------------------------------------
  String get appLocked => _t('Termul terkunci', 'Termul locked');
  String get verificationFailed =>
      _t('Verifikasi gagal atau dibatalkan', 'Verification failed or cancelled');
  String get verifying => _t('Memverifikasi…', 'Verifying…');

  // ---------------------------------------------------------------------
  // QR import
  // ---------------------------------------------------------------------
  String hostsImported(int count) =>
      _t('$count host berhasil diimpor', '$count hosts imported');
  String importHostsQuestion(int count) =>
      _t('Impor $count host?', 'Import $count hosts?');
  String get import => _t('Impor', 'Import');
  String get done => _t('Selesai', 'Done');
  String get qrImportInstructions => _t(
    'Jalankan "termul" di Mac/Linux (lihat agent/README.md), lalu '
    'scan QR yang muncul - biasanya cukup satu QR untuk beberapa host sekaligus.',
    'Run "termul" on Mac/Linux (see agent/README.md), then '
    'scan the QR code it shows - usually one QR is enough for several hosts.',
  );
}
