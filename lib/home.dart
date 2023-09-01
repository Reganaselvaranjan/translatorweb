import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/js_util.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:videoweb/constants.dart';
import 'package:videoweb/footer.dart';
import 'package:videoweb/services/firebase_services.dart';
import 'package:videoweb/widgets/loading_screen.dart';
import 'package:videoweb/widgets/showSheet_screen.dart';
import 'colors.dart';
import 'package:universal_html/html.dart' as html;
import '';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

final AuthService authService = AuthService();

class _HomeState extends State<Home> {
  late FFmpeg ffmpeg;
  bool isLoaded = false;
  String _filePath = '';
  String? displayName;
  String? email;
  String? uid;
  TextEditingController videoNameController = TextEditingController();
  TextEditingController subtitleController = TextEditingController();
  VideoPlayerController? controller;
  late Future<void> initializeVideoPlayerFuture;
  late File videoFile;
  String? videoName;
  String srtContent = '';
  String subtitles = '';
  String videoId = '';
  String videoUrl = '';

  bool isBigScreen = false;
  bool isVideoExist = false;
  bool isVideoPlaying = false;
  bool isVideoNameExist = false;
  bool isLoadingVideo = false;
  bool showLoadingPopup = false;
  bool isEditingName = false;
  bool isAudioMuted = false;
  bool isTranscribing = false;
  bool canceledVideoLoading = false;
  bool isControlVisible = false;
  bool isVideoPlayerVisible = false;
  bool isVideoDeleting = false;
  late Uint8List videoData;

  final FlutterFFmpeg flutterFFmpeg = FlutterFFmpeg();

  List<String> extractedAudioPaths = [];
  Duration videoDuration = Duration.zero;
  Duration currentPosition = Duration.zero;
  Timer? durationTimer;

  @override
  void initState() {
    super.initState();
    controller?.addListener(_updateCurrentPosition);
    _startPositionListener();
    loadUserData();
  }

  @override
  void dispose() {
    controller?.removeListener(_updateCurrentPosition);
    controller?.dispose();
    durationTimer?.cancel();
    super.dispose();
  }

  //Loading User Details//
  Future<void> loadUserData() async {
    setState(() async {
      displayName = await authService.getDisplayName();
      email = await authService.getEmail();
      uid = await authService.getUid();
    });
  }

  Widget buildIndicator() {
    if (isVideoExist) {
      return VideoProgressIndicator(
        controller ?? VideoPlayerController.network(''),
        allowScrubbing: true,
        colors: const VideoProgressColors(
            playedColor: Colors.red, backgroundColor: borderColor),
      );
    } else {
      return VideoProgressIndicator(
        VideoPlayerController.network(''), // Create an empty controller
        allowScrubbing: false,
        colors: const VideoProgressColors(
            playedColor: borderColor, backgroundColor: borderColor),
      );
    }
  }

  //Video timing while playing//
  void _updateCurrentPosition() {
    setState(() {
      currentPosition = controller?.value.position ?? Duration.zero;
    });
  }

  void _startPositionListener() {
    controller?.addListener(_updateCurrentPosition);
  }

  void onPositionChanged() {
    setState(() {
      currentPosition = controller?.value.position ?? Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String generateVideoId() {
    // Generate a unique video ID using a timestamp and a random number
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    int randomNumber = Random().nextInt(999999);
    return '$timestamp$randomNumber';
  }

  // starting of get video for web
  void _playSelectedVideo(videoUrl) {
    // Dispose of the previous controller if it exists
    if (controller != null) {
      controller!.dispose();
    }

    // Hide the loading popup
    setState(() {
      showLoadingPopup = false;
      isVideoExist = true; // Set video existence to true
    });

    // Create a VideoPlayerController
    controller = VideoPlayerController.network(videoUrl)
      ..initialize().then((_) async {
        videoDuration = controller!.value.duration;
        // Ensure the first frame is shown
        setState(() {});
        // Start listening for position updates
        controller!.addListener(() {
          setState(() {
            currentPosition = controller!.value.position;
          });
        });
        controller!.play();
        isVideoPlaying = true;
      });
    // extractAudioAndSave(videoUrl);
  }
  // Ending of get video for web

  Future<void> loadFFmpeg() async {
    ffmpeg = createFFmpeg(
        true, "https://unpkg.com/@ffmpeg/core@0.11.0/dist/ffmpeg-core.js");
    try {
      await promiseToFuture(ffmpeg.load());
      checkLoaded();
    } catch (error) {
      print("Error loading FFmpeg: $error");
    }
  }

  void checkLoaded() {
    setState(() {
      isLoaded = ffmpeg.isLoaded();
    });
  }

  String generateWebAudioOutputPath() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'audio_$timestamp.m4a';
  }

  Future<void> extractAudioAndSave(videoUrl) async {
    final audioOutputPath = generateWebAudioOutputPath();
    print('Audio output path: $audioOutputPath');
    final controller = VideoPlayerController.network(videoUrl);
    await controller.initialize();

    // Load FFmpeg
    await loadFFmpeg();

    // Build the FFmpeg command as a single string
    final command = [
      'ffmpeg',
      '-i',
      videoUrl,
      '-vn',
      '-acodec',
      'copy',
      audioOutputPath,
    ].join(' ');

// Execute the FFmpeg command
    final result = await ffmpeg.run1(command);

    // // Create a downloadable link
    // final blob = html.Blob(<
    //     dynamic>[]); // Replace with the actual blob of your extracted audio data
    // final url = html.Url.createObjectUrlFromBlob(blob);
    // final anchor = html.AnchorElement(href: url)
    //   ..setAttribute('download', audioOutputPath)
    //   ..click();

    // // Clean up the URL object
    // html.Url.revokeObjectUrl(url);

    // // Dispose of the video controller
    // controller.dispose();

    if (result.exitCode == 0) {
      print('Audio extraction successful');
    } else {
      print('Audio extraction failed');
    }
  }

  //Get video from phone storage start//
  Future<void> getVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      final videoPlayerController =
          VideoPlayerController.file(File(pickedFile.path));
      // Initialize the video player controller
      await videoPlayerController.initialize();
      await videoPlayerController.play();

      // Set the video duration
      setState(() {
        videoDuration = videoPlayerController.value.duration ?? Duration.zero;
      });

      // Start the timer to update the running duration
      durationTimer = Timer.periodic(const Duration(milliseconds: 0), (_) {
        setState(() {
          currentPosition = videoPlayerController.value.position;
        });
      });

      // Check if the video duration is less than or equal to 60 seconds
      if (videoPlayerController.value.duration != null &&
          videoPlayerController.value.duration.inSeconds > 60) {
        setState(() {
          isLoadingVideo = false;
          showLoadingPopup = false;
        });
        showLoadingPopup = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(select60MVideMsg),
            backgroundColor: primaryColor,
          ),
        );

        // Dispose the video player controller
        videoPlayerController.dispose();
        return;
      }

      setState(() {
        videoFile = File(pickedFile.path);
        videoName = pickedFile.name;
        print("print$videoFile");
        controller = VideoPlayerController.file(videoFile);
        initializeVideoPlayerFuture = controller!.initialize();
        controller!.setLooping(true);
        isVideoExist = true;
        isVideoNameExist = true;
        isLoadingVideo = true;
        showLoadingPopup = true;
      });

      await Future.delayed(const Duration(seconds: 5));
      await initializeVideoPlayerFuture;
      setState(() {
        isLoadingVideo = false;
        showLoadingPopup = false;
      });
      // Dispose the video player controller
      videoPlayerController.dispose();
    }
  }
  //Get video from phone storage End//

  // Extract audio from imported video Start//
  Future<void> extractAudioFromVideo() async {
    Directory? appDir = await getExternalStorageDirectory();
    final String outputPath =
        '${appDir?.path}/audio${DateTime.now().millisecondsSinceEpoch}.m4a';
    String videoId = generateVideoId();
    var result = await flutterFFmpeg
        .execute('-i ${videoFile.path} -vn -c:a copy $outputPath');

    if (result == 0) {
      // Audio extraction successful
      setState(() {
        extractedAudioPaths.add(outputPath);
        showLoadingPopup = false;
        print('Successfully audio extract');
      });
      uploadAudioFileToStorage(outputPath, videoId);

      // Calculate audio duration
      File audioFile = File(outputPath);
      int fileSizeInBytes = await audioFile.length();
      double bitRate = 128000; // Bit rate in bits per second (e.g., 128 kbps)
      double durationInSeconds = fileSizeInBytes * 8 / bitRate;
      print("Extracted audio duration: $durationInSeconds seconds");
      if (durationInSeconds <= 900) {
        showSubtitleSelectionSheet(context);
        saveRemainingTime(durationInSeconds);
      } else {
        showLimitAlert(context);
      }
    } else {
      //Audio extraction failed
      setState(() {
        showLoadingPopup = false;
      });
    }
  }
  // Extract audio from imported video End//

  // Api call for convert text from extracted audio start //
  Future<void> convertAudioToText(String value) async {
    String apiUrl = 'https://transcribe.whisperapi.com';
    String apiKey = 'EHCJ8SADB186HZNJPDCKZSNGMFIKI26A';
    String filePath = extractedAudioPaths.last;
    String fileType = 'm4a';

    var url = Uri.parse(apiUrl);
    var headers = {'Authorization': 'Bearer $apiKey'};
    var request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..fields.addAll({
        'fileType': fileType,
        'diarization': 'false',
        'numSpeakers': '2',
        'language': value,
        'task': 'transcribe',
      })
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    setState(() {
      isTranscribing = true;
    });
    var response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      print(responseBody);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            subtitleCreateSuccessMsg,
            style: TextStyle(color: whiteColor),
          ),
          backgroundColor: greenColor,
        ),
      );
      // // Save the subtitle to Firestore
      saveSubtitleToFirestore(responseBody);
    } else {
      print('Request failed with status: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request failed with status: ${response.statusCode}'),
          backgroundColor: greenColor,
        ),
      );
    }
  }
  // Api call for convert text from extracted audio End//

  // Save converted subtitles in Firestore start //
  void saveSubtitleToFirestore(String subtitle) {
    CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('Subtitle_user');

    usersCollection.doc(email).get().then((docSnapshot) {
      if (docSnapshot.exists) {
        usersCollection.doc(email).update({
          'transcriptions': FieldValue.arrayUnion([subtitle]),
          'timestamp': FieldValue.serverTimestamp(),
        }).then((_) {
          print('Subtitle updated for user: $uid');
        }).catchError((error) {
          print('Error updating user data: $error');
        });
      } else {
        usersCollection.doc(email).set({
          'timestamp': FieldValue.serverTimestamp(),
          'userId': uid,
          'videoId': DateTime.now().millisecondsSinceEpoch.toString(),
          'transcriptions': [
            subtitle
          ], // Store subtitles as an array of objects
        }).then((_) {
          print('New user document created: $uid');
        }).catchError((error) {
          print('Error creating user document: $error');
        });
      }

      var jsonResponse = json.decode(subtitle);
      var segments = jsonResponse['segments'];
      List<String> subtitleLines = [];

      for (var segment in segments) {
        String text = segment['text'];
        subtitleLines.add(text);
        setState(() {
          subtitles = subtitleLines.join('\n');
          isTranscribing = false;
        });
      }
    }).catchError((error) {
      print('Error checking user document: $error');
    });
  }
  // Save converted subtitles in Firestore end //

  String generateSRT(String subtitleText) {
    List<String> lines = subtitleText.split('\n');
    StringBuffer srtContent = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      srtContent.writeln((i + 1).toString());
      srtContent.writeln('00:00:00,000 --> 00:00:01,000');
      srtContent.writeln(lines[i]);
      srtContent.writeln();
    }
    return srtContent.toString();
  }

  void saveSRTToFile(String srtContent) {
    File file = File('subtitle.srt');
    file.writeAsStringSync(srtContent);
  }

  Future<void> downloadSRTFile() async {
    String srtContent = generateSRT(subtitles);
    String videoId = generateVideoId();

    Directory? appDocumentsDirectory = await getExternalStorageDirectory();
    String filePath = '${appDocumentsDirectory?.path}/subtitle.srt';

    File file = File(filePath);
    await file.writeAsString(srtContent);
    String downloadUrl = await uploadSRTFileToStorage(filePath, videoId);

    if (downloadUrl.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(srtFileCreateSuccessMsg),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(srtFileCreateFailMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> uploadSRTFileToStorage(String filePath, String videoId) async {
    try {
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('srt_files')
          .child(videoId)
          .child('subtitle.srt');

      final metadata = SettableMetadata(contentType: 'text/srt');
      UploadTask uploadTask =
          storageReference.putFile(File(filePath), metadata);
      TaskSnapshot taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        return '';
      }
    } catch (error) {
      print('Error uploading SRT file: $error');
      return '';
    }
  }

  Future<String> uploadAudioFileToStorage(
      String filePath, String videoId) async {
    try {
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('audio_files')
          .child(videoId)
          .child('audio.m4a');

      final metadata = SettableMetadata(contentType: 'audio/m4a');
      UploadTask uploadTask =
          storageReference.putFile(File(filePath), metadata);
      TaskSnapshot taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        return '';
      }
    } catch (error) {
      print('Error uploading SRT file: $error');
      return '';
    }
  }

  // Save user's remaining time and monthly limit to Firebase Firestore//
  void saveRemainingTime(double usedTimeInSeconds) {
    CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('Remaining_Time');

    DateTime now = DateTime.now();
    DateTime nextMonth =
        DateTime(now.year, now.month + 1, 1); // Start of the next month

    usersCollection.doc(email).get().then((docSnapshot) {
      if (docSnapshot.exists) {
        Map<String, dynamic>? userData =
            docSnapshot.data() as Map<String, dynamic>?;
        if (userData != null) {
          double currentRemainingTime = userData['remainingTime'] as double;
          double currentMonthlyLimit = userData['monthlyLimit'] as double;

          if (now.isAfter(nextMonth)) {
            // Reset for a new month
            currentMonthlyLimit = 900.0; // Set the monthly limit to 900 seconds
            currentRemainingTime =
                900.0; // Reset remaining time to the new limit
          }

          double newRemainingTime = currentRemainingTime - usedTimeInSeconds;

          if (newRemainingTime < 0 || usedTimeInSeconds >= 900) {
            newRemainingTime = 0;
            usedTimeInSeconds = 900; // Ensure it doesn't go negative
            // showLimitAlert(context);
          }

          usersCollection.doc(email).update({
            'remainingTime': newRemainingTime,
            'usedTime': FieldValue.increment(usedTimeInSeconds),
            'timeStamp': FieldValue.serverTimestamp(),
            'monthlyLimit': currentMonthlyLimit, // Update the monthly limit
          }).then((_) {
            print('Remaining time updated for user: $email');
          }).catchError((error) {
            print('Error updating user data: $error');
          });
        }
      } else {
        // User's document doesn't exist, create a new document
        usersCollection.doc(email).set({
          'userId': uid,
          'timeStamp': FieldValue.serverTimestamp(),
          'remainingTime': 900.0 - usedTimeInSeconds, // Initial remaining time
          'monthlyLimit': 900.0, // Initial monthly limit
          'usedTime': usedTimeInSeconds,
        }).then((_) {
          print('New user document created: $email');
        }).catchError((error) {
          print('Error creating user document: $error');
        });
      }
    }).catchError((error) {
      print('Error checking user document: $error');
    });
  }
  // Save user's remaining time and monthly limit to Firebase Firestore end//

  Future<bool> _onWillPop() async {
    return false;
  }

  void deleteVideo() {
    setState(() {
      isVideoExist = false;
      isVideoPlayerVisible = false;
      isControlVisible = false;
      isAudioMuted = false;
      isVideoDeleting = true;
      subtitles = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, Constraints) {
      if (kIsWeb) {
        if (Constraints.maxWidth > 800) {
          isBigScreen = true;

          return destophomelarge();
        } else {
          isBigScreen = false;

          return destophomelarge();
        }
      } else {
        return mobilehome();
      }
    });
  }

  Widget mobilehome() {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 226, 224, 218),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: primaryColor,
          automaticallyImplyLeading: false,
          title: const Text(appNameString),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'Item 1') {
                } else if (value == 'Item 2') {
                } else if (value == 'Item 3') {}
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                //Profile Field//
                PopupMenuItem<String>(
                  padding: const EdgeInsets.only(left: 20, right: 50),
                  value: 'Item 1',
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: primaryColor),
                      const SizedBox(width: 10),
                      TextButton(
                          onPressed: () {
                            showProfileSheet(context);
                          },
                          child: const Text(profileString,
                              style: TextStyle(color: primaryColor))),
                    ],
                  ),
                ),
                //Language Field//
                PopupMenuItem<String>(
                  padding: const EdgeInsets.only(left: 20, right: 50),
                  value: 'Item 2',
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: primaryColor),
                      const SizedBox(width: 10),
                      TextButton(
                          onPressed: () {},
                          child: const Text(languageString,
                              style: TextStyle(color: primaryColor)))
                    ],
                  ),
                ),
                //Logout Field//
                PopupMenuItem<String>(
                  padding: const EdgeInsets.only(left: 20, right: 50),
                  value: 'Item 3',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: primaryColor),
                      const SizedBox(width: 10),
                      TextButton(
                          onPressed: () async {
                            String title = sureMsg;
                            String message = askLogoutMsg;
                            showLogoutAlertDialog(
                              context,
                            );
                          },
                          child: const Text(logoutString,
                              style: TextStyle(color: primaryColor))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  //Import Video Field Start//
                  if (!isVideoExist)
                    Container(
                      margin: EdgeInsets.only(top: width / 1.5),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 226, 224, 218),
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20)),
                                side: BorderSide(color: primaryColor)),
                            padding: const EdgeInsets.all(15)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.video_collection, color: primaryColor),
                            SizedBox(width: 10),
                            Text(importVideoString,
                                style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onPressed: () {
                          getVideo();
                          showLoadingPopup = true;
                        },
                      ),
                    ),
                  const SizedBox(height: 16.0),

                  //Video Container Field Start//
                  if (isVideoExist)
                    Container(
                      width: width,
                      // padding: const EdgeInsets.only(top: 10, bottom: 10),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color.fromARGB(255, 197, 196, 196))),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 300,
                              height: 250,
                              margin: const EdgeInsets.only(
                                  top: 10, left: 10, right: 10),
                              decoration: BoxDecoration(
                                  border: Border.all(color: primaryColor),
                                  color:
                                      const Color.fromARGB(255, 201, 193, 202)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // isVideoExist?
                                      AspectRatio(
                                        aspectRatio:
                                            controller!.value.aspectRatio,
                                        child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                isControlVisible =
                                                    !isControlVisible;
                                              });
                                            },
                                            child: VideoPlayer(controller!)),
                                      )
                                      // : SizedBox(height: 200,width: 100,child: Image.asset(importImg)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Visibility(
                                        visible: isControlVisible,
                                        child: IconButton(
                                          icon: const Icon(Icons.fast_rewind,
                                              color: whiteColor, size: 40),
                                          onPressed: () {
                                            controller?.seekTo(Duration(
                                                seconds: controller!.value
                                                        .position.inSeconds -
                                                    5));
                                          },
                                        ),
                                      ),
                                      Visibility(
                                        visible: isControlVisible,
                                        child: IconButton(
                                          icon: Icon(
                                              isVideoPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: whiteColor,
                                              size: 40),
                                          onPressed: () {
                                            setState(() {
                                              if (isVideoPlaying) {
                                                controller?.pause();
                                              } else {
                                                controller?.play();
                                              }
                                              isVideoPlaying = !isVideoPlaying;
                                            });
                                          },
                                        ),
                                      ),
                                      Visibility(
                                        visible: isControlVisible,
                                        child: IconButton(
                                          icon: const Icon(Icons.fast_forward,
                                              color: whiteColor, size: 40),
                                          onPressed: () {
                                            controller?.seekTo(Duration(
                                                seconds: controller!.value
                                                        .position.inSeconds +
                                                    5));
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 20, left: 15),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: isVideoExist
                                          ? Text(
                                              "${_formatDuration(controller!.value.position)} / ${_formatDuration(videoDuration)}",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13))
                                          : const Text('00:00'),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 10, left: 15),
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: IconButton(
                                        icon: Icon(
                                            isAudioMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            if (isAudioMuted) {
                                              controller?.setVolume(1.0);
                                            } else {
                                              controller?.setVolume(0.0);
                                            }
                                            isAudioMuted = !isAudioMuted;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                      bottom: 10,
                                      left: 20,
                                      right: 20,
                                      child: buildIndicator()),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20))),
                                padding: const EdgeInsets.all(15),
                                maximumSize: Size(width - 100, height / 10)),
                            onPressed: () {
                              extractAudioFromVideo();
                              showSubtitleSelectionSheet(context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.closed_caption),
                                SizedBox(width: 10),
                                Text(createSubtitleString,
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: [
                              if (isTranscribing)
                                const Center(child: LoadingScreen())
                              else if (subtitles.isNotEmpty)
                                Text(subtitles),
                              const SizedBox(height: 20),
                              // subtitles.isNotEmpty
                              // ?
                              Container(
                                margin: EdgeInsets.only(left: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                              255, 226, 224, 218),
                                          shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(20)),
                                              side: BorderSide(
                                                  color: primaryColor)),
                                          padding: const EdgeInsets.all(10)),
                                      onPressed: () {
                                        String title = 'Are you sure to leave?';
                                        String message =
                                            'You will not able to revert this';
                                        showDiscardConfirmAlert(
                                            context, title, message);
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.delete,
                                              color: primaryColor),
                                          SizedBox(width: 10),
                                          Text(discardString,
                                              style: TextStyle(
                                                  color: primaryColor)),
                                        ],
                                      ),
                                    ),
                                    subtitles.isNotEmpty
                                        ? ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryColor,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    20))),
                                                padding:
                                                    const EdgeInsets.all(10)),
                                            onPressed: () {
                                              downloadSRTFile();
                                            },
                                            child: Row(
                                              children: const [
                                                Icon(Icons.download),
                                                SizedBox(width: 10),
                                                Text(downloadSRTString),
                                              ],
                                            ))
                                        : Container()
                                    // if (isVideoExist)
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showLoadingPopup)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Text(loadingMsg, textAlign: TextAlign.center),
                        SizedBox(height: 20),
                        CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void showsubtitlepopup2(
    BuildContext context,
  ) {
    String selectedLanguage = 'en';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        double width = MediaQuery.of(context).size.width;
        double height = MediaQuery.of(context).size.height;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            content: SizedBox(
              height: height / 2,
              width: !isBigScreen ? width / 1.5 : width / 2.8,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(generateSubtitleMsg,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor)),
                        IconButton(
                            onPressed: () {
                              Get.back();
                            },
                            icon: const Icon(Icons.close, color: primaryColor))
                      ],
                    ),
                    const Divider(color: borderColor),
                    const SizedBox(height: 20),
                    const Text(selectTranslateLanguageMsg,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: DropdownButtonFormField<String>(
                        value: selectedLanguage,
                        onChanged: (newValue) {
                          selectedLanguage = newValue!;
                        },
                        decoration: const InputDecoration(
                            filled: true,
                            hintText: selectLanguageMsg,
                            hintStyle: TextStyle(fontSize: 20),
                            prefixIcon:
                                Icon(Icons.language, color: primaryColor),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide:
                                  BorderSide(color: primaryColor, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                                borderSide:
                                    BorderSide(color: primaryColor, width: 2)),
                            errorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            )),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'en',
                            child: Text('English'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'fr',
                            child: Text('French'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'de',
                            child: Text('German'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'es',
                            child: Text('Spanish'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            Get.back(); // Close the bottom sheet
                            await convertAudioToText(selectedLanguage);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor),
                          child: const Text(generateSubtitleString),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                            onPressed: () {
                              Get.back();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: borderColor),
                            child: const Text(closeString)),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(translationMsg,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: primaryColor)),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void showSubtitleSelectionSheet(
    BuildContext context,
  ) {
    // Home homeScreen = Get.put(Home());
    String selectedLanguage = 'en';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (BuildContext context) {
        double width = MediaQuery.of(context).size.width;
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          width: 100,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(generateSubtitleMsg,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor)),
                  IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: const Icon(Icons.close, color: primaryColor))
                ],
              ),
              const Divider(color: borderColor),
              const SizedBox(height: 20),
              const Text(selectTranslateLanguageMsg,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedLanguage,
                onChanged: (newValue) {
                  selectedLanguage = newValue!;
                },
                decoration: InputDecoration(
                    filled: true,
                    hintText: selectLanguageMsg,
                    hintStyle: TextStyle(fontSize: width / 5 * 0.2),
                    prefixIcon: const Icon(Icons.language, color: primaryColor),
                    contentPadding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(color: primaryColor, width: 2)),
                    errorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'en',
                    child: Text('English'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'fr',
                    child: Text('French'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'de',
                    child: Text('German'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'es',
                    child: Text('Spanish'),
                  ),
                ],
              ),
              const Divider(color: borderColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      Get.back(); // Close the bottom sheet
                      await convertAudioToText(selectedLanguage);
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text(generateSubtitleString),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () {
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: borderColor),
                      child: const Text(closeString)),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Text(translationMsg,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: primaryColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  void showLimitAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Monthly Limit Reached'),
          content: const Text('You have reached your monthly usage limit.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(okString),
            ),
          ],
        );
      },
    );
  }

  showDiscardConfirmAlert(BuildContext context, String title, String message) {
    Widget okbtn = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text(cancelString,
                style: TextStyle(color: borderColor, fontSize: 18))),
        TextButton(
            onPressed: () async {
              deleteVideo();
              Get.back();
            },
            child: const Text('Discard',
                style: TextStyle(color: Colors.green, fontSize: 18))),
      ],
    );
    AlertDialog alert = AlertDialog(
      title: Center(
          child: Column(
        children: [
          const CircleAvatar(
              backgroundColor: Color.fromARGB(255, 197, 196, 196),
              child: Icon(
                CupertinoIcons.exclamationmark,
                color: primaryColor,
              )),
          Text(title, style: const TextStyle(color: Colors.red, fontSize: 15)),
        ],
      )),
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: primaryColor)),
      actions: [okbtn],
    );
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        });
  }

  Widget destophomelarge() {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Material(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          logoImg,
                          height: height / 12,
                        ),
                        const Text(
                          appNameString,
                          style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: whiteColor),
                        ),
                      ],
                    ),
                    if (isBigScreen)
                      Row(
                        children: [
                          NavbarButton(
                            icon: Icons.person,
                            text: profileString,
                            onTap: () {
                              showProfileSheet(context);
                            },
                          ),
                          const SizedBox(
                            width: 40,
                          ),
                          NavbarButton(
                            icon: Icons.language,
                            text: languageString,
                            onTap: () {},
                          ),
                          const SizedBox(
                            width: 40,
                          ),
                          NavbarButton(
                            icon: Icons.logout,
                            text: logoutString,
                            onTap: () async {
                              String title = sureMsg;
                              String message = askLogoutMsg;
                              showLogoutAlertDialog(
                                context,
                              );
                              if (isVideoPlaying) {
                                controller?.pause();
                              }
                            },
                          ),
                        ],
                      ),
                    if (!isBigScreen)
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.menu,
                          color: whiteColor,
                        ),
                        offset: const Offset(0, 48),
                        onSelected: (value) {
                          if (value == 'Item 1') {
                          } else if (value == 'Item 2') {
                          } else if (value == 'Item 3') {}
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          //Profile Field//
                          PopupMenuItem<String>(
                            padding: const EdgeInsets.only(left: 20, right: 50),
                            value: 'Item 1',
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: primaryColor),
                                const SizedBox(width: 10),
                                TextButton(
                                    onPressed: () {
                                      showProfileSheet(context);
                                    },
                                    child: const Text(profileString,
                                        style: TextStyle(color: primaryColor))),
                              ],
                            ),
                          ),
                          //Language Field//
                          PopupMenuItem<String>(
                            padding: const EdgeInsets.only(left: 20, right: 50),
                            value: 'Item 2',
                            child: Row(
                              children: [
                                const Icon(Icons.language, color: primaryColor),
                                const SizedBox(width: 10),
                                TextButton(
                                    onPressed: () {},
                                    child: const Text(languageString,
                                        style: TextStyle(color: primaryColor)))
                              ],
                            ),
                          ),
                          //Logout Field//
                          PopupMenuItem<String>(
                            padding: const EdgeInsets.only(left: 20, right: 50),
                            value: 'Item 3',
                            child: Row(
                              children: [
                                const Icon(Icons.logout, color: primaryColor),
                                const SizedBox(width: 10),
                                TextButton(
                                    onPressed: () async {
                                      String title = sureMsg;
                                      String message = askLogoutMsg;
                                      showLogoutAlertDialog(context);
                                    },
                                    child: const Text(logoutString,
                                        style: TextStyle(color: primaryColor))),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 40, left: 40),
                      child: Row(
                        children: [
                          SizedBox(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 30,
                                ),
                                if (!isVideoExist)
                                  SizedBox(
                                    width: width / 2,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                              255, 226, 224, 218),
                                          shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(20)),
                                              side: BorderSide(
                                                  color: primaryColor)),
                                          padding: const EdgeInsets.all(15)),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.video_collection,
                                            color: primaryColor,
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          Text(
                                            importVideoString,
                                            style: TextStyle(
                                                color: primaryColor,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      onPressed: () {
                                        // Open the file picker dialog
                                        final input =
                                            html.FileUploadInputElement()
                                              ..accept = 'video/*';
                                        input.click();
                                        input.onChange.listen((event) {
                                          final file = input.files!.first;
                                          videoUrl =
                                              html.Url.createObjectUrlFromBlob(
                                                  file);
                                          _playSelectedVideo(videoUrl);
                                        });

                                        // Show the loading popup
                                        setState(() {
                                          showLoadingPopup = true;
                                        });
                                      },
                                    ),
                                  ),
                                const SizedBox(
                                  height: 30,
                                ),
                                Container(
                                  height:
                                      isVideoExist ? height / 2 : height / 3,
                                  width: isBigScreen ? width / 2 : width / 1.3,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: primaryColor),
                                  ),
                                  child: isVideoExist
                                      ? AspectRatio(
                                          aspectRatio:
                                              controller!.value.aspectRatio,
                                          child: VideoPlayer(controller!))
                                      : SizedBox(
                                          height: height / 3,
                                          width: isBigScreen
                                              ? width / 2
                                              : width / 1.3,
                                          child: Image.asset(importImg),
                                        ),
                                ),
                                SizedBox(
                                    width:
                                        isBigScreen ? width / 2 : width / 1.3,
                                    child: buildIndicator()),

                                //Video Duration Field Start//
                                Container(
                                  width: isBigScreen ? width / 2 : width / 1.3,
                                  color: Colors.black.withOpacity(0.5),
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                      child: isVideoExist
                                          ? Text(
                                              "${_formatDuration(currentPosition)} / ${_formatDuration(videoDuration)}",
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            )
                                          : const Text(
                                              '00:00/00:00',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: blackColor),
                                            )),
                                ),
                                //Video Duration Field End//
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fast_rewind,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        controller?.seekTo(Duration(
                                            seconds: controller!
                                                    .value.position.inSeconds -
                                                10));
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isVideoPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isVideoPlaying) {
                                            controller?.pause();
                                          } else {
                                            controller?.play();
                                          }
                                          isVideoPlaying = !isVideoPlaying;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fast_forward,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        controller?.seekTo(Duration(
                                            seconds: controller!
                                                    .value.position.inSeconds +
                                                10));
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 20,
                                ),
                                SizedBox(
                                  width: isBigScreen ? width / 2 : width / 1.3,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(20))),
                                        padding: const EdgeInsets.all(15)),
                                    onPressed: () {
                                      extractAudioAndSave(videoUrl);
                                      // showsubtitlepopup2(context);
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.closed_caption),
                                        SizedBox(width: 10),
                                        Text(
                                          createSubtitleString,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height: 10,
                                ),
                                if (isVideoExist)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color.fromARGB(
                                                    255, 226, 224, 218),
                                            shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(20)),
                                                side: BorderSide(
                                                    color: primaryColor)),
                                            padding: const EdgeInsets.all(10)),
                                        onPressed: () {
                                          String title =
                                              'Are you sure to leave?';
                                          String message =
                                              'You will not able to revert this';
                                          showDiscardConfirmAlert(
                                              context, title, message);
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.delete,
                                                color: primaryColor),
                                            SizedBox(width: 10),
                                            Text(discardString,
                                                style: TextStyle(
                                                    color: primaryColor)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      isVideoExist
                                          ? ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                  padding:
                                                      const EdgeInsets.all(10)),
                                              onPressed: () {
                                                downloadSRTFile();
                                              },
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.download),
                                                  SizedBox(width: 10),
                                                  Text(downloadSRTString),
                                                ],
                                              ))
                                          : Container()
                                    ],
                                  ),
                                const SizedBox(height: 20),

                                if (!isBigScreen)
                                  Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: primaryColor),
                                      ),
                                      child: isVideoExist
                                          ? Container(
                                              margin: const EdgeInsets.all(10),
                                              child:
                                                  StreamBuilder<QuerySnapshot>(
                                                stream: FirebaseFirestore
                                                    .instance
                                                    .collection('subtitles')
                                                    .orderBy('timestamp',
                                                        descending: true)
                                                    .snapshots(),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: primaryColor,
                                                      ),
                                                    );
                                                  } else if (snapshot
                                                      .hasError) {
                                                    return const Text(
                                                        'Error loading subtitles');
                                                  } else {
                                                    List<QueryDocumentSnapshot>
                                                        subtitles =
                                                        snapshot.data!.docs;
                                                    if (subtitles.isEmpty) {
                                                      return const Text(
                                                          'No subtitles available');
                                                    }

                                                    String jsonData =
                                                        subtitles.first.get(
                                                                'transcription')
                                                            as String;

                                                    Map<String, dynamic>
                                                        jsonMap =
                                                        json.decode(jsonData);

                                                    String subtitleText =
                                                        jsonMap['text']
                                                            as String;

                                                    return Text(
                                                      subtitleText,
                                                      textAlign:
                                                          TextAlign.justify,
                                                      style: const TextStyle(
                                                          color: primaryColor,
                                                          fontSize: 20),
                                                    );
                                                  }
                                                },
                                              ),
                                            )
                                          : SizedBox(
                                              height: height / 2,
                                              width: width / 1.3,
                                              child: const Center(
                                                child: Text(
                                                  'No Subtitles Available',
                                                  style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 20),
                                                ),
                                              ),
                                            ))
                              ],
                            ),
                          ),
                          if (isBigScreen)
                            const SizedBox(
                              width: 50,
                            ),
                          if (isBigScreen)
                            Container(
                                margin: const EdgeInsets.only(top: 50),
                                width: width / 2 - 150,
                                height: height / 1.5,
                                decoration: BoxDecoration(
                                  border: Border.all(color: primaryColor),
                                ),
                                child: isVideoExist
                                    ? Container(
                                        margin: const EdgeInsets.all(10),
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('subtitles')
                                              .orderBy('timestamp',
                                                  descending: true)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: primaryColor,
                                                ),
                                              );
                                            } else if (snapshot.hasError) {
                                              return const Text(
                                                  'Error loading subtitles');
                                            } else {
                                              List<QueryDocumentSnapshot>
                                                  subtitles =
                                                  snapshot.data!.docs;
                                              if (subtitles.isEmpty) {
                                                return const Text(
                                                    'No subtitles available');
                                              }

                                              String jsonData = subtitles.first
                                                      .get('transcription')
                                                  as String;

                                              Map<String, dynamic> jsonMap =
                                                  json.decode(jsonData);

                                              String subtitleText =
                                                  jsonMap['text'] as String;

                                              return Text(
                                                subtitleText,
                                                textAlign: TextAlign.justify,
                                                style: const TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 20),
                                              );
                                            }
                                          },
                                        ),
                                      )
                                    : SizedBox(
                                        height: height / 2,
                                        width: width,
                                        child: const Center(
                                          child: Text(
                                            'No Subtitles Available',
                                            style: TextStyle(
                                                color: primaryColor,
                                                fontSize: 20),
                                          ),
                                        ),
                                      ))
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    const FootBar(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class NavbarButton extends StatelessWidget {
  final String text; // The text to display in the button
  final IconData icon; // The icon data to display
  final VoidCallback onTap; // The function to execute when the button is tapped

  const NavbarButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
