import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:wakelock/wakelock.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

/*
VM:
IP: 10.102.201.92
Stream: digitalSignage

AWS:
IP: 13.127.84.210
Stream: mystream
*/

const server_ip = '13.127.84.210';
var m3u8_url = 'http://'+server_ip+':8888/mystream/index.m3u8';
var list_url= 'http://'+server_ip+':9997/v3/paths/list';

void main() {
  runApp(const VideoApp());
}

/// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;
  var prev_time='';

  @override
  void initState() {
    super.initState();
    setState(() {
      Wakelock.enable();
      // You could also use Wakelock.toggle(on: true);
    });
    const oneSec = Duration(seconds:5);
    Timer.periodic(oneSec, (Timer t) => check_video());
    get_url();
    print('loading url '+ m3u8_url);
    _controller = VideoPlayerController.networkUrl(Uri.parse(m3u8_url))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {
          _controller.play();
          //_controller.dispose();
        });
      });
    _controller.addListener(() {
      if(_controller.value.isBuffering){
        print('buffering');
      }else if(_controller.value.hasError){
        print('error');
      }else if(_controller.value.position == _controller.value.duration){
        print('completed');
      }
    });

  }

  Future<void> get_url() async {
    late VideoPlayerController newController;
    var url = Uri.parse(list_url);
    // Await the http get response, then decode the json-formatted response.
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse =
      convert.jsonDecode(response.body) as Map<String, dynamic>;
      if (jsonResponse['items'].isEmpty) {
        print('Array is empty, nothing is being played');
      } else {
        print(jsonResponse['items'][0]);
        m3u8_url = 'http://' + server_ip + ':8888/' +
            jsonResponse['items'][0]['name'] + '/index.m3u8';
        print('streaming link: ' + m3u8_url);
      }
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  Future<void> check_video() async {
    late VideoPlayerController newController;
    var url = Uri.parse(list_url);
    // Await the http get response, then decode the json-formatted response.
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse =
      convert.jsonDecode(response.body) as Map<String, dynamic>;
      if(jsonResponse['items'].isEmpty) {
        print('Array is empty, nothing is being played');
      }
      else {
        m3u8_url = 'http://' + server_ip + ':8888/' +
            jsonResponse['items'][0]['name'] + '/index.m3u8';
        if (prev_time == '') {
          prev_time = jsonResponse['items'][0]['readyTime'];
        }
        else if (prev_time == jsonResponse['items'][0]['readyTime']) {
          print('src has not changed');
        }
        else {
          prev_time = jsonResponse['items'][0]['readyTime'];
          print('Source changed. loading url ' + m3u8_url);
          newController = VideoPlayerController.networkUrl(Uri.parse(m3u8_url),
          )
            ..initialize().then((_) {
              setState(() {
                _controller.dispose(); // Dispose the old controller
                _controller = newController; // Assign the new controller
                _controller.play();
              });
            });
        }
      }
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
              : Container(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    setState(() {
      Wakelock.disable();
      // You could also use Wakelock.toggle(on: false);
    });
    _controller.dispose();
  }
}