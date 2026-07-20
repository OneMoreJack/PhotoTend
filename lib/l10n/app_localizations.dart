import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum AppLanguage {
  zh(Locale('zh')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  final Locale locale;
}

class RePhotoLocaleScope extends InheritedWidget {
  const RePhotoLocaleScope({
    super.key,
    required this.language,
    required this.setLanguage,
    required super.child,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> setLanguage;

  static RePhotoLocaleScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RePhotoLocaleScope>();
  }

  @override
  bool updateShouldNotify(RePhotoLocaleScope oldWidget) {
    return language != oldWidget.language;
  }
}

abstract class AppLocalizations {
  const AppLocalizations();

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizationsZh();
  }

  String get appTitle;
  String get photosTab;
  String get importTab;
  String get trashTitle;
  String get recentKicker;
  String get libraryKicker;
  String get recentTitle;
  String get allPhotosTitle;
  String get emptyLibraryMessage;
  String get backTooltip;
  String get trashEmptyTitle;
  String get trashEmptySubtitle;
  String get menuTooltip;
  String get infoTooltip;
  String get openInGallery;
  String get importFolder;
  String get settingsTitle;
  String get languageTitle;
  String get chooseLanguageTitle;
  String get cumulativeDeleted;
  String get monthCompleteTitle;
  String get monthCompleteSubtitle;
  String get replay;
  String get importTitle;
  String get importEmptyTitle;
  String get chooseStorageSource;
  String get refresh;
  String get connectStorageCard;
  String get chooseStorageCardTitle;
  String get authorizeStorageHint;
  String get manualAuthorizeLocation;
  String get manualAuthorizeHint;
  String get deleteFromStorageTitle;
  String deleteFromStorageMessage(int count);
  String get cancel;
  String get delete;
  String get importTo;
  String get librarySection;
  String get yourLibrary;
  String get systemLibrarySubtitle;
  String get albumsSection;
  String get newAlbum;
  String get noUserAlbums;
  String itemsCount(int count);
  String get createAlbumTitle;
  String get albumNameHint;
  String get create;
  String get unknownDate;
  String monthDay(int month, int day);
  String get select;
  String get deselect;
  String get moreActions;
  String get chooseAnotherStorageCard;
  String get loadRawFiles;
  String selectedCount(int count);
  String get importAll;
  String get importSelected;
  String get scanning;
  String get currentSelection;
  String get pendingImport;
  String get calculating;
  String localizeImportMessage(String message);
  String deletionPhotoCount(int count);
  String deletionVideoCount(int count);
  String deletionSaved(String sizeText, bool hasUnknownSize);
}

class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  @override
  String get appTitle => 'PhotoTend';

  @override
  String get photosTab => 'Photos';

  @override
  String get importTab => 'Import';

  @override
  String get trashTitle => 'Trash';

  @override
  String get recentKicker => 'Last Week';

  @override
  String get libraryKicker => 'Library';

  @override
  String get recentTitle => 'Last Week';

  @override
  String get allPhotosTitle => 'All Photos';

  @override
  String get emptyLibraryMessage => 'No photos or videos to show';

  @override
  String get backTooltip => 'Back';

  @override
  String get trashEmptyTitle => 'Trash is empty';

  @override
  String get trashEmptySubtitle =>
      'Photos you remove while browsing will wait here before they are permanently deleted.';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get infoTooltip => 'Info';

  @override
  String get openInGallery => 'Open in gallery';

  @override
  String get importFolder => 'Import Folder';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get chooseLanguageTitle => 'Choose Language';

  @override
  String get cumulativeDeleted => 'Cumulative deleted';

  @override
  String get monthCompleteTitle => 'This month is complete';

  @override
  String get monthCompleteSubtitle =>
      'You have reviewed every photo and video.';

  @override
  String get replay => 'Replay';

  @override
  String get importTitle => 'Import';
  @override
  String get importEmptyTitle => 'No importable content found';
  @override
  String get chooseStorageSource => 'Choose Storage Source';
  @override
  String get refresh => 'Refresh';
  @override
  String get connectStorageCard => 'Connect an external storage card.';
  @override
  String get chooseStorageCardTitle => 'Choose a storage card to import';
  @override
  String get authorizeStorageHint => 'Tap to grant access and load photos';
  @override
  String get manualAuthorizeLocation => 'Choose location manually';
  @override
  String get manualAuthorizeHint => 'Use when no storage card is detected';
  @override
  String get deleteFromStorageTitle => 'Delete from storage card?';
  @override
  String deleteFromStorageMessage(int count) =>
      'Permanently delete $count photos from the storage card.';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get importTo => 'Import to';
  @override
  String get librarySection => 'Library';
  @override
  String get yourLibrary => 'Your Library';
  @override
  String get systemLibrarySubtitle => 'Import to the system media library';
  @override
  String get albumsSection => 'Albums';
  @override
  String get newAlbum => 'New Album...';
  @override
  String get noUserAlbums => 'No user-created albums found';
  @override
  String itemsCount(int count) => '$count items';
  @override
  String get createAlbumTitle => 'New Album';
  @override
  String get albumNameHint => 'Album name';
  @override
  String get create => 'Create';
  @override
  String get unknownDate => 'Unknown date';
  @override
  String monthDay(int month, int day) => '$month/$day';
  @override
  String get select => 'Select';
  @override
  String get deselect => 'Deselect';
  @override
  String get moreActions => 'More actions';
  @override
  String get chooseAnotherStorageCard => 'Choose another storage card';
  @override
  String get loadRawFiles => 'Load RAW files';
  @override
  String selectedCount(int count) => '$count selected';
  @override
  String get importAll => 'Import All';
  @override
  String get importSelected => 'Import Selected';
  @override
  String get scanning => 'Scanning';
  @override
  String get currentSelection => 'Current selection';
  @override
  String get pendingImport => 'Pending import';
  @override
  String get calculating => 'Calculating...';
  @override
  String localizeImportMessage(String message) {
    final deleted = RegExp(r'^已从储存卡删除 (\d+) 个项目$').firstMatch(message);
    if (deleted != null) {
      return 'Deleted ${deleted.group(1)} items from the storage card';
    }
    final partialDelete = RegExp(
      r'^已删除 (\d+) 个项目，(\d+) 个删除失败。$',
    ).firstMatch(message);
    if (partialDelete != null) {
      return 'Deleted ${partialDelete.group(1)} items; '
          '${partialDelete.group(2)} failed.';
    }
    return switch (message) {
      '请连接外接储存卡，或选择储存卡目录。' =>
        'Connect an external storage card or choose its folder.',
      '读取外接储存卡失败，请重新选择或刷新。' =>
        'Could not read the external storage card. Choose it again or refresh.',
      '没有找到可导入的照片或视频。' => 'No importable photos or videos found.',
      '删除失败，请确认储存卡目录允许写入后重试。' =>
        'Delete failed. Make sure the storage card folder allows writes and try again.',
      '导入完成' => 'Import complete',
      '部分照片导入失败，可重新选择后重试。' =>
        'Some photos could not be imported. Select them and try again.',
      _ => message,
    };
  }

  @override
  String deletionPhotoCount(int count) {
    return '$count photo${count == 1 ? '' : 's'}';
  }

  @override
  String deletionVideoCount(int count) {
    return '$count video${count == 1 ? '' : 's'}';
  }

  @override
  String deletionSaved(String sizeText, bool hasUnknownSize) {
    return '$sizeText${hasUnknownSize ? '+' : ''} saved';
  }
}

class AppLocalizationsZh extends AppLocalizations {
  const AppLocalizationsZh();

  @override
  String get appTitle => '理好相册';

  @override
  String get photosTab => '照片';

  @override
  String get importTab => '导入';

  @override
  String get trashTitle => '回收站';

  @override
  String get recentKicker => '最近';

  @override
  String get libraryKicker => '图库';

  @override
  String get recentTitle => '近一周';

  @override
  String get allPhotosTitle => '所有照片';

  @override
  String get emptyLibraryMessage => '暂无可显示的照片或视频';

  @override
  String get backTooltip => '返回';

  @override
  String get trashEmptyTitle => '回收站是空的';

  @override
  String get trashEmptySubtitle => '浏览时移除的照片会先放在这里，确认后再永久删除。';

  @override
  String get menuTooltip => '菜单';

  @override
  String get infoTooltip => '信息';

  @override
  String get openInGallery => '在图库中打开';

  @override
  String get importFolder => '导入文件夹';

  @override
  String get settingsTitle => '设置';

  @override
  String get languageTitle => '语言';

  @override
  String get chooseLanguageTitle => '选择语言';

  @override
  String get cumulativeDeleted => '累计删除';

  @override
  String get monthCompleteTitle => '当前月份已经浏览完毕';

  @override
  String get monthCompleteSubtitle => '这个月的照片和视频都看完了';

  @override
  String get replay => '再看一遍';

  @override
  String get importTitle => '导入';
  @override
  String get importEmptyTitle => '未发现可导入内容';
  @override
  String get chooseStorageSource => '选择存储源';
  @override
  String get refresh => '刷新';
  @override
  String get connectStorageCard => '请连接外接储存卡。';
  @override
  String get chooseStorageCardTitle => '选择要导入的储存卡';
  @override
  String get authorizeStorageHint => '点按后授权访问并加载照片';
  @override
  String get manualAuthorizeLocation => '手动授权位置';
  @override
  String get manualAuthorizeHint => '检测不到储存卡时使用';
  @override
  String get deleteFromStorageTitle => '从储存卡删除？';
  @override
  String deleteFromStorageMessage(int count) => '将从储存卡上永久删除 $count 张照片。';
  @override
  String get cancel => '取消';
  @override
  String get delete => '删除';
  @override
  String get importTo => '导入至';
  @override
  String get librarySection => '图库';
  @override
  String get yourLibrary => '你的图库';
  @override
  String get systemLibrarySubtitle => '导入到系统媒体库';
  @override
  String get albumsSection => '相簿';
  @override
  String get newAlbum => '新建相簿...';
  @override
  String get noUserAlbums => '系统相册中暂无用户创建的相簿';
  @override
  String itemsCount(int count) => '$count 个项目';
  @override
  String get createAlbumTitle => '新建相簿';
  @override
  String get albumNameHint => '相簿名';
  @override
  String get create => '创建';
  @override
  String get unknownDate => '未知日期';
  @override
  String monthDay(int month, int day) => '$month月$day日';
  @override
  String get select => '选择';
  @override
  String get deselect => '取消选择';
  @override
  String get moreActions => '更多操作';
  @override
  String get chooseAnotherStorageCard => '重选储存卡';
  @override
  String get loadRawFiles => '加载 RAW 文件';
  @override
  String selectedCount(int count) => '已选 $count';
  @override
  String get importAll => '导入全部';
  @override
  String get importSelected => '导入选中';
  @override
  String get scanning => '正在扫描';
  @override
  String get currentSelection => '当前选择';
  @override
  String get pendingImport => '待导入';
  @override
  String get calculating => '统计中…';
  @override
  String localizeImportMessage(String message) => message;

  @override
  String deletionPhotoCount(int count) {
    return '$count 张照片';
  }

  @override
  String deletionVideoCount(int count) {
    return '$count 个视频';
  }

  @override
  String deletionSaved(String sizeText, bool hasUnknownSize) {
    return '已节省 $sizeText${hasUnknownSize ? '+' : ''}';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final localizations = switch (locale.languageCode) {
      'zh' => const AppLocalizationsZh(),
      _ => const AppLocalizationsEn(),
    };
    return SynchronousFuture(localizations);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
