// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:videoweb/colors.dart';
// import 'package:videoweb/constants.dart';
// import 'package:videoweb/footer.dart';
// import 'package:videoweb/home.dart';
// import 'package:videoweb/services/firebase_services.dart';

// class Login extends StatefulWidget {
//   const Login({Key? key}) : super(key: key);

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   bool isBigScreen = false;
//   bool passwordVisible = true;
//   bool isLoading = false;
//   bool showOverlay = false;
//   String phoneNumber = "";

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(builder: (context, Constraints) {
//       if (kIsWeb) {
//         if (Constraints.maxWidth > 900) {
//           isBigScreen = true;

//           return destopLoginlarge();
//         } else {
//           isBigScreen = false;

//           return destopLoginlarge();
//         }
//       } else {
//         return mobileLogin();
//       }
//     });
//   }

//   @override
//   Widget mobileLogin() {
//     double width = MediaQuery.of(context).size.width;
//     double height = MediaQuery.of(context).size.width;
//     return GestureDetector(
//       onTap: () => FocusScope.of(context).unfocus(),
//       child: Scaffold(
//         backgroundColor: primaryColor,
//         body: Stack(
//           children: [
//             Container(
//               height: height / 0.55,
//               decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(
//                       bottomLeft: Radius.circular(50),
//                       bottomRight: Radius.circular(50))),
//             ),
//             Container(
//               margin: const EdgeInsets.symmetric(horizontal: 20),
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     SizedBox(
//                       height: height / 3,
//                     ),
//                     Image.asset(
//                       logoImg,
//                       height: height / 1.25,
//                     ),
//                     TextFormField(
//                       keyboardType: TextInputType.number,
//                       onChanged: (value) {
//                         setState(() {
//                           phoneNumber = value;
//                         });
//                       },
//                       decoration: const InputDecoration(
//                           prefixIcon: Icon(Icons.phone),
//                           hintText: phoneNoString,
//                           hintStyle: TextStyle(color: Colors.black),
//                           enabledBorder: OutlineInputBorder(
//                               borderSide: BorderSide(color: Colors.black),
//                               borderRadius:
//                                   BorderRadius.all(Radius.circular(20))),
//                           focusedBorder: OutlineInputBorder(
//                               borderSide: BorderSide(color: Colors.black),
//                               borderRadius:
//                                   BorderRadius.all(Radius.circular(20)))),
//                     ),
//                     const SizedBox(height: 16.0),
//                     const SizedBox(height: 20.0),
//                     ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryColor,
//                           shape: const RoundedRectangleBorder(
//                               borderRadius:
//                                   BorderRadius.all(Radius.circular(20))),
//                           padding: const EdgeInsets.all(15)),
//                       onPressed: () async {
//                         Get.to(const Home());
//                         // authService.verifyPhoneNumber(phoneNumber);
//                       },
//                       child: const Text(
//                         loginString,
//                         style: TextStyle(fontSize: 20),
//                       ),
//                     ),
//                     const SizedBox(
//                       height: 20,
//                     ),
//                     GestureDetector(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Image.asset(
//                             googleImg,
//                             height: 30,
//                             width: 30,
//                           ),
//                           const SizedBox(
//                             width: 10,
//                           ),
//                           const Text(
//                             signInGoogleString,
//                             style: TextStyle(fontSize: 16),
//                           )
//                         ],
//                       ),
//                       onTap: () async {
//                         setState(() {
//                           isLoading = true; // Start loading
//                         });

//                         AuthService authService = AuthService();
//                         await authService.initAuthService();

//                         User? user = await AuthService().signInWithGoogle();
//                         setState(() {
//                           isLoading = false; // Stop loading
//                           if (user != null) {
//                             showOverlay = true; // Show the overlay
//                             Future.delayed(const Duration(seconds: 2), () {
//                               setState(() {
//                                 showOverlay = false;
//                               });
//                               Get.to(const Home());
//                             });
//                           }
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             if (isLoading) // Show the loading indicator conditionally
//               Container(
//                 color: Colors.black54,
//                 child: const Center(
//                   child: CircularProgressIndicator(),
//                 ),
//               ),
//             if (showOverlay)
//               Center(
//                 child: Container(
//                   color: Colors.black54,
//                   child: Center(
//                     child: Align(
//                       alignment: Alignment.bottomCenter,
//                       child: Container(
//                         margin: const EdgeInsets.only(bottom: 20),
//                         width: width,
//                         color: Colors.white,
//                         child: const Padding(
//                           padding: EdgeInsets.all(14.0),
//                           child: Text(
//                             signInSuccessMsg,
//                             textAlign: TextAlign.center,
//                             style: TextStyle(color: Colors.green, fontSize: 15),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget destopLoginlarge() {
//     double width = MediaQuery.of(context).size.width;
//     double height = MediaQuery.of(context).size.height;
//     return Scaffold(
//       backgroundColor: whiteColor,
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.start,
//         children: [
//           Container(
//             color: primaryColor,
//             child: Padding(
//               padding: const EdgeInsets.all(15.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Image.asset(
//                         logoImg,
//                         height: height / 10,
//                       ),
//                       const SizedBox(
//                         width: 10,
//                       ),
//                       const Text(
//                         appNameString,
//                         style: TextStyle(
//                             fontSize: 25,
//                             fontWeight: FontWeight.bold,
//                             color: whiteColor),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       if (isBigScreen)
//                         Image.asset(
//                           webbgimg,
//                           height: height,
//                           width: width / 2,
//                         ),
//                       Container(
//                         width: isBigScreen ? width / 3 : 400,
//                         margin: const EdgeInsets.symmetric(
//                             horizontal: 50, vertical: 100),
//                         decoration: BoxDecoration(
//                             border: Border.all(width: 1, color: primaryColor),
//                             borderRadius: BorderRadius.circular(10)),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             const SizedBox(height: 50),
//                             Image.asset(
//                               logoImg,
//                               height: height / 5,
//                             ),
//                             const SizedBox(
//                               height: 20,
//                             ),
//                             SizedBox(
//                               width: 250,
//                               child: TextFormField(
//                                 keyboardType: TextInputType.number,
//                                 decoration: const InputDecoration(
//                                     prefixIcon: Icon(Icons.phone),
//                                     hintText: phoneNoString,
//                                     hintStyle: TextStyle(color: primaryColor),
//                                     enabledBorder: OutlineInputBorder(
//                                         borderSide:
//                                             BorderSide(color: primaryColor),
//                                         borderRadius: BorderRadius.all(
//                                             Radius.circular(20))),
//                                     focusedBorder: OutlineInputBorder(
//                                         borderSide:
//                                             BorderSide(color: primaryColor),
//                                         borderRadius: BorderRadius.all(
//                                             Radius.circular(20)))),
//                               ),
//                             ),
//                             const SizedBox(
//                               height: 20,
//                             ),
//                             SizedBox(
//                               width: 150,
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                     backgroundColor: primaryColor,
//                                     shape: const RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.all(
//                                             Radius.circular(15))),
//                                     padding: const EdgeInsets.all(15)),
//                                 onPressed: () {
//                                   Get.to(const Home());
//                                 },
//                                 child: const Text(
//                                   loginString,
//                                   style: TextStyle(fontSize: 20),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(
//                               height: 20,
//                             ),
//                             GestureDetector(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Image.asset(
//                                     googleImg,
//                                     height: 30,
//                                     width: 30,
//                                   ),
//                                   const SizedBox(
//                                     width: 10,
//                                   ),
//                                   const Text(
//                                     signInGoogleString,
//                                     style: TextStyle(fontSize: 16),
//                                   )
//                                 ],
//                               ),
//                               onTap: () async {
//                                 setState(() {
//                                   isLoading = true; // Start loading
//                                 });

//                                 AuthService authService = AuthService();
//                                 await authService.initAuthService();

//                                 User? user =
//                                     await AuthService().signInWithGoogle();
//                                 setState(() {
//                                   isLoading = false; // Stop loading
//                                   if (user != null) {
//                                     showOverlay = true; // Show the overlay
//                                     Future.delayed(const Duration(seconds: 2),
//                                         () {
//                                       setState(() {
//                                         showOverlay = false;
//                                       });
//                                       Get.to(const Home());
//                                     });
//                                   }
//                                 });
//                               },
//                             ),
//                             const SizedBox(
//                               height: 30,
//                             ),
//                           ],
//                         ),
//                       )
//                     ],
//                   ),
//                   const FootBar(),
//                 ],
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
