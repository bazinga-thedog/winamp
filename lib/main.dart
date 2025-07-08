import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Player & Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AudioPlayerRecorderScreen(),
    );
  }
}

class AudioPlayerRecorderScreen extends StatefulWidget {
  @override
  _AudioPlayerRecorderScreenState createState() => _AudioPlayerRecorderScreenState();
}

class _AudioPlayerRecorderScreenState extends State<AudioPlayerRecorderScreen> {
  late AudioPlayer _audioPlayer;
  AudioRecorder? _audioRecorder;
  
  String? _recordingPath;
  bool _isRecording = false;
  bool _isPlayingSample = false;
  bool _isPlayingRecording = false;
  bool _isRecordingSupported = false;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    // Only initialize recorder on supported platforms
    _initializeRecorder();
    
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlayingSample = state.playing;
        _isPlayingRecording = state.playing;
      });
    });
  }

  Future<void> _initializeRecorder() async {
    // Check if recording is supported on this platform
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      setState(() {
        _isRecordingSupported = false;
      });
      return;
    }
    
    try {
      _audioRecorder = AudioRecorder();
      setState(() {
        _isRecordingSupported = true;
      });
    } catch (e) {
      setState(() {
        _isRecordingSupported = false;
      });
      print('Recording not supported on this platform: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder?.dispose();
    super.dispose();
  }

  Future<void> _playSampleAudio() async {
    try {
      if (_isPlayingSample) {
        await _audioPlayer.stop();
      } else {
        await _audioPlayer.setAsset('assets/sample.mp3');
        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing sample audio: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecordingSupported || _audioRecorder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording not supported on this platform. Please run on iOS or Android device.')),
      );
      return;
    }

    try {
      if (await _audioRecorder!.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder!.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: _recordingPath!,
        );
        
        setState(() {
          _isRecording = true;
        });
        
        // Auto-stop after 5 seconds
        Future.delayed(Duration(seconds: 5), () {
          if (_isRecording) {
            _stopRecording();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording for 5 seconds...')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_audioRecorder == null) return;
    
    try {
      await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No recording available')),
      );
      return;
    }

    try {
      if (_isPlayingRecording) {
        await _audioPlayer.stop();
      } else {
        await _audioPlayer.setFilePath(_recordingPath!);
        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Player & Recorder'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sample Audio Player Button
            Container(
              width: 200,
              height: 60,
              margin: EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton.icon(
                onPressed: _playSampleAudio,
                icon: Icon(_isPlayingSample ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlayingSample ? 'Stop Sample' : 'Play Sample'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Voice Recorder Button
            Container(
              width: 200,
              height: 60,
              margin: EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton.icon(
                onPressed: (!_isRecordingSupported || _isRecording) ? null : _startRecording,
                icon: Icon(_isRecording ? Icons.mic : Icons.mic_none),
                label: Text(_isRecording 
                    ? 'Recording...' 
                    : (_isRecordingSupported ? 'Record 5sec' : 'Not Supported')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording 
                      ? Colors.red 
                      : (_isRecordingSupported ? Colors.green : Colors.grey),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Recording Player Button
            Container(
              width: 200,
              height: 60,
              margin: EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton.icon(
                onPressed: (_recordingPath == null || !_isRecordingSupported) ? null : _playRecording,
                icon: Icon(_isPlayingRecording ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlayingRecording ? 'Stop Recording' : 'Play Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_recordingPath == null || !_isRecordingSupported) ? Colors.grey : Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Status Text
            Container(
              margin: EdgeInsets.only(top: 32),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Status:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  if (_isRecording)
                    Text('🎤 Recording...', style: TextStyle(color: Colors.red, fontSize: 16)),
                  if (_isPlayingSample)
                    Text('🎵 Playing sample audio', style: TextStyle(color: Colors.blue, fontSize: 16)),
                  if (_isPlayingRecording)
                    Text('🎵 Playing recording', style: TextStyle(color: Colors.orange, fontSize: 16)),
                  if (!_isRecording && !_isPlayingSample && !_isPlayingRecording)
                    Text(_isRecordingSupported ? 'Ready' : 'Recording only available on iOS/Android', 
                         style: TextStyle(color: _isRecordingSupported ? Colors.green : Colors.orange, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}