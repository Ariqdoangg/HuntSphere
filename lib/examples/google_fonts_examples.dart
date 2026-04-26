import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Examples of using Google Fonts
class GoogleFontsExample extends StatelessWidget {
  const GoogleFontsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Fonts Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Using different font families
            Text(
              'Roboto Font',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Poppins Font',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Playfair Display Font',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Montserrat Font',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Custom text style with Google Fonts
            Text(
              'Custom Styled Text',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.blue[700],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            
            // Button with Google Fonts
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Styled Button'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme example with Google Fonts
class GoogleFontsThemeExample extends StatelessWidget {
  const GoogleFontsThemeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Fonts Theme',
      theme: ThemeData(
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme.copyWith(
            displayLarge: GoogleFonts.lato(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            headlineMedium: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            bodyLarge: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      home: const GoogleFontsExample(),
    );
  }
}
