import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF4),
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FAQItem(
              number: '1',
              question: 'What is PlantFollow?',
              answer:
                  'PlantFollow is an AI-powered plant identifier and care guide that helps you instantly identify plants, diagnose issues, and track your plant care effortlessly.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '2',
              question: 'Is the app free to use?',
              answer:
                  'PlantFollow offers a free basic experience. You can unlock unlimited identifications, detailed care tips, and advanced features with a premium plan.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '3',
              question: 'Do I need an internet connection?',
              answer:
                  'Yes, an active internet connection ensures fast and accurate AI identification.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '4',
              question: 'How do I get the best identification results?',
              answer:
                  'Take a photo in good lighting, keep the plant in the centre, and capture leaves, stems, or flowers clearly.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '5',
              question: 'What can I identify using PlantFollow?',
              answer:
                  'You can identify indoor plants, outdoor plants, flowers, trees, succulents, fruits, herbs, mushrooms, and more.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '6',
              question: 'Can I save and organise my plants?',
              answer:
                  'Yes - the My Garden feature allows you to save, categorise, and track all your plants in one place.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '7',
              question: 'Does PlantFollow send watering reminders?',
              answer:
                  'Absolutely! You can receive smart watering, fertilising, and repotting reminders based on each plant\'s needs.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '8',
              question: 'Can I use PlantFollow on multiple devices?',
              answer:
                  'Yes, if you\'re signed into the same Apple ID and have an active subscription.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '9',
              question: 'Is my data safe?',
              answer:
                  'PlantFollow follows strict Apple privacy guidelines, and your photos are processed securely.',
            ),
            const SizedBox(height: 24),
            _FAQItem(
              number: '10',
              question: 'How often do you update the app?',
              answer:
                  'We release regular updates with new species recognition, improved accuracy, UI enhancements, and new care tips.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  const _FAQItem({
    required this.number,
    required this.question,
    required this.answer,
  });

  final String number;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              answer,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

