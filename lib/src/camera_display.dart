import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_crop/image_crop.dart';
import 'package:image_picker_plus/src/custom_packages/crop_image/crop_image.dart';
import 'package:image_picker_plus/src/entities/app_theme.dart';
import 'package:image_picker_plus/src/entities/selected_image_details.dart';
import 'package:image_picker_plus/src/entities/tabs_texts.dart';
import 'package:image_picker_plus/src/utilities/enum.dart';
import 'package:image_picker_plus/src/video_layout/record_count.dart';
import 'package:image_picker_plus/src/video_layout/record_fade_animation.dart';
import 'package:photo_manager/photo_manager.dart';

class CustomCameraDisplay extends StatefulWidget {
  final bool selectedVideo;
  final AppTheme appTheme;
  final TabsTexts tapsNames;
  final bool enableCamera;
  final bool enableVideo;
  final VoidCallback moveToVideoScreen;
  final ValueNotifier<File?> selectedCameraImage;
  final ValueNotifier<bool> redDeleteText;
  final ValueChanged<bool> replacingTabBar;
  final ValueNotifier<bool> clearVideoRecord;
  final AsyncValueSetter<SelectedImagesDetails>? sendRequestFunction;
  final ValueNotifier<File?> videoRecordFile;

  const CustomCameraDisplay({
    Key? key,
    required this.appTheme,
    required this.tapsNames,
    required this.sendRequestFunction,
    required this.selectedCameraImage,
    required this.enableCamera,
    required this.videoRecordFile,
    required this.enableVideo,
    required this.redDeleteText,
    required this.selectedVideo,
    required this.replacingTabBar,
    required this.clearVideoRecord,
    required this.moveToVideoScreen,
  }) : super(key: key);

  @override
  CustomCameraDisplayState createState() => CustomCameraDisplayState();
}

class CustomCameraDisplayState extends State<CustomCameraDisplay> {
  ValueNotifier<bool> startVideoCount = ValueNotifier(false);

  bool initializeDone = false;
  bool allPermissionsAccessed = true;

  List<CameraDescription>? cameras;
  late CameraController controller;

  final cropKey = GlobalKey<CustomCropState>();

  Flash currentFlashMode = Flash.auto;
  late Widget videoStatusAnimation;
  int selectedCamera = 0;

  @override
  void dispose() {
    startVideoCount.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    videoStatusAnimation = const SizedBox();
    _initializeCamera();

    super.initState();
  }

  Future<void> _initializeCamera() async {
    try {
      PermissionState state = await PhotoManager.requestPermissionExtend();
      if (!state.hasAccess || !state.isAuth) {
        allPermissionsAccessed = false;
        return;
      }
      allPermissionsAccessed = true;
      cameras = await availableCameras();
      if (!mounted) return;
      controller = CameraController(
        cameras![0],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      initializeDone = true;
    } catch (e) {
      allPermissionsAccessed = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.appTheme.primaryColor,
      child: allPermissionsAccessed ? (initializeDone ? buildBody() : loadingProgress()) : failedPermissions(),
    );
  }

  Widget failedPermissions() {
    return Center(
      child: Text(
        widget.tapsNames.acceptAllPermissions,
        style: TextStyle(color: widget.appTheme.focusColor),
      ),
    );
  }

  Center loadingProgress() {
    return Center(
      child: CircularProgressIndicator(
        color: widget.appTheme.focusColor,
        strokeWidth: 1,
      ),
    );
  }

  Widget buildBody() {
    Color whiteColor = widget.appTheme.primaryColor;
    File? selectedImage = widget.selectedCameraImage.value;
    double previewHeight = MediaQuery.of(context).size.height / 2;
    return Column(
      children: [
        appBar(),
        Flexible(
          child: Stack(
            children: [
              if (selectedImage == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: CameraPreview(controller),
                ),
              ] else ...[
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    color: whiteColor,
                    height: previewHeight + 10,
                    width: double.infinity,
                    child: buildCrop(selectedImage),
                  ),
                )
              ],
              buildFlashIcons(),
              buildPickImageContainer(whiteColor, context),
            ],
          ),
        ),
      ],
    );
  }

  Align buildPickImageContainer(Color whiteColor, BuildContext context) {
    double previewHeight = MediaQuery.of(context).size.height / 2;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: previewHeight - 100,
        color: whiteColor,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: RecordCount(
                  appTheme: widget.appTheme,
                  startVideoCount: startVideoCount,
                  makeProgressRed: widget.redDeleteText,
                  clearVideoRecord: widget.clearVideoRecord,
                ),
              ),
            ),
            const Spacer(),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  padding: const EdgeInsets.all(60),
                  child: Align(
                    alignment: Alignment.center,
                    child: cameraButton(context),
                  ),
                ),
                Positioned(bottom: 120, child: videoStatusAnimation),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Align buildFlashIcons() {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () {
          setState(() {
            currentFlashMode = currentFlashMode == Flash.off ? Flash.auto : (currentFlashMode == Flash.auto ? Flash.on : Flash.off);
          });
          currentFlashMode == Flash.on
              ? controller.setFlashMode(FlashMode.torch)
              : currentFlashMode == Flash.off
                  ? controller.setFlashMode(FlashMode.off)
                  : controller.setFlashMode(FlashMode.auto);
        },
        icon: Icon(currentFlashMode == Flash.on ? Icons.flash_on_rounded : (currentFlashMode == Flash.auto ? Icons.flash_auto_rounded : Icons.flash_off_rounded),
            color: Colors.white),
      ),
    );
  }

  CustomCrop buildCrop(File selectedImage) {
    String path = selectedImage.path;
    bool isThatVideo = path.contains("mp4", path.length - 5);
    return CustomCrop(
      image: selectedImage,
      isThatImage: !isThatVideo,
      key: cropKey,
      alwaysShowGrid: true,
      paintColor: widget.appTheme.primaryColor,
    );
  }

  AppBar appBar() {
    Color whiteColor = widget.appTheme.primaryColor;
    Color blackColor = widget.appTheme.focusColor;
    File? selectedImage = widget.selectedCameraImage.value;
    return AppBar(
      backgroundColor: whiteColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.clear_rounded, color: blackColor, size: 30),
        onPressed: () {
          Navigator.of(context).maybePop(null);
        },
      ),
      actions: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          switchInCurve: Curves.easeIn,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_outlined,
              color: Colors.black,
              size: 30,
            ),
            onPressed: () async {
              if (widget.videoRecordFile.value != null && !widget.clearVideoRecord.value) {
                Uint8List byte = await widget.videoRecordFile.value!.readAsBytes();
                SelectedByte selectedByte = SelectedByte(
                  isThatImage: false,
                  selectedFile: widget.videoRecordFile.value!,
                  selectedByte: byte,
                );
                SelectedImagesDetails details = SelectedImagesDetails(
                  multiSelectionMode: false,
                  selectedFiles: [selectedByte],
                  aspectRatio: 1.0,
                );
                if (!mounted) return;
                if (widget.sendRequestFunction != null) {
                  await widget.sendRequestFunction!(details);
                } else {
                  Navigator.of(context).maybePop(details);
                }
              } else if (selectedImage != null) {
                File? croppedByte = await cropImage(selectedImage);
                File img = croppedByte ?? selectedImage;
                Uint8List byte = await img.readAsBytes();

                SelectedByte selectedByte = SelectedByte(
                  isThatImage: true,
                  selectedFile: img,
                  selectedByte: byte,
                );

                SelectedImagesDetails details = SelectedImagesDetails(
                  selectedFiles: [selectedByte],
                  multiSelectionMode: false,
                  aspectRatio: 1.0,
                );
                if (!mounted) return;
                if (widget.sendRequestFunction != null) {
                  await widget.sendRequestFunction!(details);
                } else {
                  Navigator.of(context).maybePop(details);
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Future<File?> cropImage(File imageFile) async {
    await ImageCrop.requestPermissions();
    final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      return null;
    }
    final sample = await ImageCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / scale).round(),
    );
    final File file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );
    sample.delete();
    return file;
  }

  GestureDetector cameraButton(BuildContext context) {
    Color whiteColor = widget.appTheme.primaryColor;
    return GestureDetector(
      onTap: widget.enableCamera ? onPress : null,
      onLongPress: widget.enableVideo ? onLongTap : null,
      onLongPressUp: widget.enableVideo ? onLongTapUp : onPress,
      child: CircleAvatar(
        backgroundColor: Colors.grey[400],
        radius: 40,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: whiteColor,
        ),
      ),
    );
  }

  onPress() async {
    try {
      if (!widget.selectedVideo) {
        final image = await controller.takePicture();
        File selectedImage = File(image.path);
        setState(() {
          widget.selectedCameraImage.value = selectedImage;
          widget.replacingTabBar(true);
        });
      } else {
        setState(() {
          videoStatusAnimation = buildFadeAnimation();
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  onLongTap() {
    controller.startVideoRecording();
    widget.moveToVideoScreen();
    setState(() {
      startVideoCount.value = true;
    });
  }

  onLongTapUp() async {
    setState(() {
      startVideoCount.value = false;
      widget.replacingTabBar(true);
    });
    XFile video = await controller.stopVideoRecording();
    widget.videoRecordFile.value = File(video.path);
  }

  RecordFadeAnimation buildFadeAnimation() {
    return RecordFadeAnimation(child: buildMessage());
  }

  Widget buildMessage() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            color: Color.fromARGB(255, 54, 53, 53),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.tapsNames.holdButtonText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Center(
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: Color.fromARGB(255, 49, 49, 49),
              size: 65,
            ),
          ),
        ),
      ],
    );
  }
}
