import 'package:flutter/material.dart';
import 'package:videoweb/colors.dart';
import 'package:videoweb/constants.dart';

class FootBar extends StatefulWidget {
  const FootBar({super.key});

  @override
  State<FootBar> createState() => _FootBarState();
}

class _FootBarState extends State<FootBar> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Container(
      color: Color.fromARGB(255, 29, 28, 28),
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  logoImg,
                  height: height / 15,
                ),
                const Text(
                  footernamestring,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: whiteColor),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              findusonstring,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(
              height: 15,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  color: Colors.white,
                  onPressed: () {},
                  icon: const Icon(Icons.facebook_rounded),
                ),
                const SizedBox(
                  width: 15,
                ),
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.tiktok_rounded),
                  onPressed: () {},
                ),
                const SizedBox(
                  width: 15,
                ),
                IconButton(
                  color: Colors.white,
                  onPressed: () {},
                  icon: const Icon(Icons.facebook_rounded),
                ),
                const SizedBox(
                  width: 15,
                ),
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.tiktok_rounded),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    termsstring,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    privacystring,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.copyright, color: Colors.white),
                SizedBox(
                  width: 10,
                ),
                Text(
                  kelaxastring,
                  style: TextStyle(color: Colors.white),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
