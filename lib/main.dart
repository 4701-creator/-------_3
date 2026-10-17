import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محمل يوتيوب',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  String _statusMessage = '';
  double _progress = 0.0;

  // طلب أذونات التخزين
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    }
    return true;
  }

  // دالة بدء التحميل
  Future<void> _startDownload() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMsg('الرجاء إدخال رابط يوتيوب صحيح');
      return;
    }

    bool hasPermission = await _requestPermission();
    if (!hasPermission) {
      _showMsg('تم رفض إذن التخزين!');
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'جاري جلب بيانات الفيديو...';
      _progress = 0.0;
    });

    var yt = YoutubeExplode();
    try {
      // الحصول على تفاصيل الفيديو
      var video = await yt.videos.get(url);
      var manifest = await yt.videos.streamsClient.getManifest(url);
      var streamInfo = manifest.muxed.withHighestQuality();

      var stream = yt.videos.streamsClient.get(streamInfo);
      
      // تحديد مجلد التحميل في الهاتف (Downloads)
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // تنظيف عنوان الفيديو ليكون اسماً صالحاً للملف
      String safeTitle = video.title.replaceAll(Reg(r'[^\w\s]+'), '');
      String filePath = '${directory!.path}/$safeTitle.${streamInfo.container.name}';
      
      var file = File(filePath);
      var fileStream = file.openWrite();

      int totalLength = streamInfo.size.totalBytes;
      int downloaded = 0;

      // الاستماع للبيانات وتنزيلها مع حساب النسبة المئوية
      await for (var data in stream) {
        downloaded += data.length;
        fileStream.add(data);
        setState(() {
          _progress = downloaded / totalLength;
          _statusMessage = 'جاري التحميل: ${(_progress * 100).toStringAsFixed(0)}%';
        });
      }

      await fileStream.flush();
      await fileStream.close();

      setState(() {
        _statusMessage = 'تم التحميل بنجاح في مجلد التنزيلات!';
      });
      _showMsg('تم حفظ الفيديو بنجاح!');
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء التحميل';
      });
      _showMsg('خطأ: $e');
    } finally {
      yt.close();
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محمل فيديوهات يوتيوب'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'رابط فيديو يوتيوب',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 10),
            ],
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('تحميل الفيديو', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}