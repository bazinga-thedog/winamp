import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Video Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  File? _videoFile;
  bool _isPicking = false; // To prevent multiple file pickers opening

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // For Android 13+ (API 33+), request media video permission
    if (Platform.isAndroid && await Permission.videos.status != PermissionStatus.granted) {
      await Permission.videos.request();
    }

    if (status.isGranted) {
      print('Storage permission granted');
    } else {
      print('Storage permission denied');
      // Optionally show a dialog to the user explaining why permission is needed
    }
  }

  Future<void> _pickAndPlayVideo() async {
    if (_isPicking) return; // Prevent multiple pickers

    setState(() {
      _isPicking = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        _videoFile = File(result.files.single.path!);
        await _initializeVideoPlayer(_videoFile!);
      } else {
        // User canceled the picker
        print('Video picking cancelled');
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    } finally {
      setState(() {
        _isPicking = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer(File videoFile) async {
    // Dispose of previous controller if exists
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = VideoPlayerController.file(videoFile);

    try {
      await _controller!.initialize();
      setState(() {}); // Rebuild to show the video player
      _controller!.play();
    } catch (e) {
      print('Error initializing video player: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing video: $e')),
      );
      _controller = null; // Clear controller on error
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Local MP4'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_controller != null && _controller!.value.isInitialized)
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            else if (_videoFile != null)
              const CircularProgressIndicator() // Show loading when video is selected but not initialized
            else
              const Text('No video selected'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isPicking ? null : _pickAndPlayVideo,
                  child: const Text('Pick and Play MP4'),
                ),
                if (_controller != null && _controller!.value.isInitialized)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: FloatingActionButton(
                      onPressed: () {
                        setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        });
                      },
                      child: Icon(
                        _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}