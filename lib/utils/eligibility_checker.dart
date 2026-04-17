import '../config/constants.dart';

class EligibilityChecker {
  // Check if donor is eligible based on BMI
  static bool checkBmiEligibility(double bmi) {
    return bmi >= AppConstants.minBmiForDonation &&
        bmi <= AppConstants.maxBmiForDonation;
  }

  // Calculate BMI from weight(kg) and height(cm)
  static double calculateBmi(double weightKg, double heightCm) {
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  // Get BMI category
  static String getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    if (bmi < 35) return 'Obese';
    return 'Severely Obese';
  }

  // Check hemoglobin eligibility
  static bool checkHemoglobinEligibility(double hemoglobin, String gender) {
    if (gender.toLowerCase() == 'male') {
      return hemoglobin >= AppConstants.minHemoglobinMale;
    }
    return hemoglobin >= AppConstants.minHemoglobinFemale;
  }

  // Check age eligibility
  static bool checkAgeEligibility(int age) {
    return age >= AppConstants.minDonorAge &&
        age <= AppConstants.maxDonorAge;
  }

  // Full eligibility check
  static Map<String, dynamic> checkFullEligibility({
    required int age,
    required double bmi,
    required double hemoglobin,
    required String gender,
  }) {
    final ageOk = checkAgeEligibility(age);
    final bmiOk = checkBmiEligibility(bmi);
    final hbOk = checkHemoglobinEligibility(hemoglobin, gender);
    final isEligible = ageOk && bmiOk && hbOk;

    final reasons = <String>[];
    if (!ageOk) {
      reasons.add(
          'Age must be between ${AppConstants.minDonorAge}-${AppConstants.maxDonorAge} years');
    }
    if (!bmiOk) {
      reasons.add(
          'BMI must be between ${AppConstants.minBmiForDonation}-${AppConstants.maxBmiForDonation}');
    }
    if (!hbOk) {
      final min = gender.toLowerCase() == 'male'
          ? AppConstants.minHemoglobinMale
          : AppConstants.minHemoglobinFemale;
      reasons.add('Hemoglobin must be at least $min g/dL');
    }

    return {
      'isEligible': isEligible,
      'reasons': reasons,
      'ageOk': ageOk,
      'bmiOk': bmiOk,
      'hemoglobinOk': hbOk,
    };
  }
}
