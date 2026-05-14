import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/data/mobile/mobile_permissions_service.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/albums/album_summary_page.dart';
import 'package:rephoto/features/home/home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.controller,
    this.pickDirectoryPath,
    this.scanImportedDirectory,
  });

  final HomeController? controller;
  final Future<String?> Function()? pickDirectoryPath;
  final Future<List<MediaItem>> Function(String path)? scanImportedDirectory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final HomeController _controller;
  late final bool _ownsController;
  final MobilePermissionsService _permissionsService =
      MethodChannelMobilePermissionsService();
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  PermanentDeleteService? _deleteService;
  String? _mobileLibraryStatusMessage;
  int _mediaLoadSession = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        HomeController(initialMediaItems: const <MediaItem>[]);
    if (_ownsController) {
      _bootstrapMobileLibrary();
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      WidgetsBinding.instance.removeObserver(this);
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ownsController) {
      _refreshMediaLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlbumSummaryPage(
      controller: _controller,
      statusMessage: _mobileLibraryStatusMessage,
      deleteService: _deleteService,
      pickDirectoryPath: widget.pickDirectoryPath,
      scanImportedDirectory: widget.scanImportedDirectory,
    );
  }

  Future<void> _bootstrapMobileLibrary() async {
    final session = ++_mediaLoadSession;
    setState(() => _mobileLibraryStatusMessage = '正在加载媒体库…');
    try {
      final permission = await _permissionsService.requestMediaReadPermission();
      if (!mounted || session != _mediaLoadSession) {
        return;
      }
      if (permission == MediaPermissionStatus.denied) {
        _deleteService = null;
        setState(() {
          _mobileLibraryStatusMessage = '未获得媒体权限，请在系统设置中允许访问照片和视频。';
        });
        return;
      }

      _deleteService = PermanentDeleteService.real(
        deleteExecutor: _mobileMediaRepository.permanentDelete,
      );
      const initialPageSize = 60;
      final items = await _mobileMediaRepository.fetchMediaPage(
        offset: 0,
        limit: initialPageSize,
      );
      if (!mounted || session != _mediaLoadSession) {
        return;
      }

      final validItems = items
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isEmpty) {
        setState(() => _mobileLibraryStatusMessage = null);
        return;
      }

      _controller.replaceMediaItems(validItems);
      setState(() => _mobileLibraryStatusMessage = null);
      _loadRemainingMediaInBackground(
        session: session,
        startOffset: items.length,
      );
    } on MissingPluginException {
      if (mounted) {
        setState(() => _mobileLibraryStatusMessage = null);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _mobileLibraryStatusMessage = '读取媒体库失败：${error.code}';
        });
      }
    }
  }

  Future<void> _loadRemainingMediaInBackground({
    required int session,
    required int startOffset,
  }) async {
    const pageSize = 300;
    var offset = startOffset;
    while (mounted && session == _mediaLoadSession) {
      final page = await _mobileMediaRepository.fetchMediaPage(
        offset: offset,
        limit: pageSize,
      );
      if (!mounted || session != _mediaLoadSession || page.isEmpty) {
        return;
      }
      final validItems = page
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isNotEmpty) {
        _controller.addMediaItems(validItems);
      }
      offset += page.length;
      if (page.length < pageSize) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _refreshMediaLibrary() async {
    try {
      final items = await _mobileMediaRepository.fetchMediaPage(
        offset: 0,
        limit: 300,
      );
      if (!mounted || items.isEmpty) {
        return;
      }
      final validItems = items
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isNotEmpty) {
        _controller.addMediaItems(validItems);
      }
    } catch (_) {
      // Best-effort refresh.
    }
  }
}
