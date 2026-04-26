class FirstAidResponses {
  static const Map<String, List<String>> _keywords = {
    'burn': ['burn', 'burned', 'burning', 'scald', 'hot', 'fire'],
    'bleed': ['bleed', 'bleeding', 'blood', 'wound', 'cut', 'slash'],
    'cpr': ['cpr', 'cardiac', 'heart', 'chest', 'pulse', 'breathe',
            'unconscious', 'not breathing'],
    'fracture': ['fracture', 'broken', 'bone', 'sprain', 'crack'],
    'snake': ['snake', 'snakebite', 'venom', 'bite', 'reptile'],
    'choke': ['choke', 'choking', 'airway', 'throat', 'heimlich'],
    'shock': ['shock', 'pale', 'sweating', 'faint', 'dizzy', 'collapse'],
    'poison': ['poison', 'poisoning', 'toxic', 'swallowed', 'chemical'],
    'drowning': ['drown', 'drowning', 'water', 'submerged'],
    'allergy': ['allergy', 'allergic', 'anaphylaxis', 'swelling', 'rash',
                'hives'],
    'eye': ['eye', 'eyes', 'vision', 'blind', 'chemical in eye'],
    'fever': ['fever', 'temperature', 'hot', 'sweating', 'chills'],
    'head': ['head', 'concussion', 'skull', 'headache', 'hit head'],
    'hello': ['hello', 'hi', 'help', 'what', 'how', 'start', 'guide'],
  };

  static const Map<String, FirstAidResponse> _responses = {
    'burn': FirstAidResponse(
      title: '🔥 Burns & Scalds',
      severity: 'High',
      steps: [
        'Cool the burn under cool (not cold) running water for 20 minutes',
        'Remove clothing/jewellery near the burn (unless stuck to skin)',
        'Cover loosely with clean cling film or non-fluffy material',
        'Do NOT use ice, butter, toothpaste or any cream',
        'Take over-the-counter painkillers if needed',
        'Keep the person warm to prevent shock',
      ],
      warnings: [
        'Do NOT burst blisters — risk of infection',
        'Do NOT remove anything stuck to the burn',
        'For chemical burns — brush off dry chemical first, then rinse',
      ],
      callEmergency: [
        'Burns larger than the size of your hand',
        'Burns on face, hands, feet, genitals, or major joints',
        'Deep burns (white or charred skin)',
        'Chemical or electrical burns',
        'Person is a child or elderly',
      ],
    ),

    'bleed': FirstAidResponse(
      title: '🩸 Bleeding',
      severity: 'Critical',
      steps: [
        'Apply firm direct pressure on the wound with a clean cloth',
        'Keep pressing continuously for at least 10 minutes',
        'If cloth soaks through, add more on top — do NOT remove',
        'Raise the injured area above heart level if possible',
        'Once bleeding slows, bandage firmly',
        'Keep the person still and calm',
      ],
      warnings: [
        'Do NOT remove the cloth if soaked — add more on top',
        'Do NOT remove embedded objects from the wound',
        'Do NOT apply tourniquet unless trained (last resort only)',
      ],
      callEmergency: [
        'Bleeding does not stop after 10 minutes of pressure',
        'Blood is spurting (arterial bleed)',
        'Large or deep wound',
        'Wound is on chest, abdomen, or neck',
      ],
    ),

    'cpr': FirstAidResponse(
      title: '❤️ CPR (Cardiac Arrest)',
      severity: 'Critical',
      steps: [
        'Check if the person is responsive — tap shoulders, shout',
        'Call 112 (emergency) immediately or ask someone to call',
        'Lay person on firm flat surface, tilt head back',
        'Give 30 chest compressions — push hard 2 inches deep, 100/min',
        'Give 2 rescue breaths (tilt head, lift chin, pinch nose)',
        'Continue 30:2 cycle until help arrives or person responds',
        'If untrained — hands-only CPR is also effective',
      ],
      warnings: [
        'Do NOT stop CPR unless trained help arrives',
        'Hands-only CPR (no rescue breaths) is acceptable',
        'It is normal to feel ribs crack — continue anyway',
      ],
      callEmergency: [
        'Always — CPR is only needed in cardiac arrest',
        'Call 112 before starting CPR if possible',
      ],
    ),

    'fracture': FirstAidResponse(
      title: '🦴 Fractures & Broken Bones',
      severity: 'High',
      steps: [
        'Keep the person still — do NOT move the injured area',
        'Immobilize the fracture with a splint or padding',
        'Apply a cold pack wrapped in cloth to reduce swelling',
        'Elevate the limb if it is not the spine or neck',
        'Monitor for signs of shock (pale, cold, sweating)',
        'Support the injured area in the position found',
      ],
      warnings: [
        'Do NOT try to straighten the bone',
        'Do NOT move a person with suspected spinal injury',
        'Open fractures (bone visible) — cover with clean cloth',
      ],
      callEmergency: [
        'Suspected neck or spine injury',
        'Open fracture (bone visible through skin)',
        'Fracture of hip, pelvis, or thigh',
        'Person shows signs of shock',
      ],
    ),

    'snake': FirstAidResponse(
      title: '🐍 Snake Bite',
      severity: 'Critical',
      steps: [
        'Keep the person calm and still — movement spreads venom',
        'Immobilize the bitten limb below heart level',
        'Remove tight clothing, watches, rings near the bite',
        'Mark the edge of swelling with a pen and time it',
        'Take note of the snake\'s appearance if safe to do so',
        'Transport to hospital IMMEDIATELY',
      ],
      warnings: [
        'Do NOT cut the wound or suck out venom',
        'Do NOT apply a tourniquet or ice',
        'Do NOT give alcohol or pain medication',
        'Do NOT use electric shock methods',
      ],
      callEmergency: [
        'Always — all snake bites require hospital assessment',
        'Antivenom can only be given at a hospital',
      ],
    ),

    'choke': FirstAidResponse(
      title: '😮 Choking',
      severity: 'Critical',
      steps: [
        'Ask "Are you choking?" — if they cannot speak or cough, act fast',
        'Give 5 firm back blows between shoulder blades with heel of hand',
        'Give 5 abdominal thrusts (Heimlich manoeuvre):',
        '  — Stand behind person, arms around waist',
        '  — Make fist above navel, pull sharply inward and upward',
        'Alternate 5 back blows and 5 abdominal thrusts',
        'If person becomes unconscious — start CPR',
      ],
      warnings: [
        'Do NOT perform abdominal thrusts on pregnant women or infants',
        'For infants — use 5 back blows and 5 chest thrusts only',
        'Do NOT do blind finger sweeps in the mouth',
      ],
      callEmergency: [
        'Object does not dislodge after several cycles',
        'Person loses consciousness',
        'Child or infant is choking',
      ],
    ),

    'shock': FirstAidResponse(
      title: '😰 Shock',
      severity: 'Critical',
      steps: [
        'Lay the person down and raise legs 30cm (unless head/spine injury)',
        'Keep them warm with a blanket',
        'Do NOT give food or water',
        'Loosen tight clothing around neck, chest, waist',
        'Monitor breathing and pulse every minute',
        'Comfort and reassure the person',
        'Call emergency immediately',
      ],
      warnings: [
        'Do NOT raise legs if head, neck or spine injury is suspected',
        'Do NOT leave the person alone',
        'Do NOT give anything to eat or drink',
      ],
      callEmergency: [
        'Always — shock is life-threatening',
        'Signs: pale/grey skin, cold/clammy, rapid weak pulse, confusion',
      ],
    ),

    'poison': FirstAidResponse(
      title: '☠️ Poisoning',
      severity: 'Critical',
      steps: [
        'Call Poison Control or 112 immediately',
        'Try to identify what was swallowed and when',
        'If conscious and alert — do NOT induce vomiting unless told to',
        'If chemical on skin — remove clothing and rinse with water',
        'If in eyes — flush with clean water for 15–20 minutes',
        'Save the container or substance for medical staff',
      ],
      warnings: [
        'Do NOT induce vomiting without professional advice',
        'Do NOT give milk or water unless instructed',
        'Corrosive substances can cause more damage coming back up',
      ],
      callEmergency: [
        'Always — even if person seems fine now',
        'Bring the container/substance to hospital',
      ],
    ),

    'allergy': FirstAidResponse(
      title: '🤧 Severe Allergic Reaction (Anaphylaxis)',
      severity: 'Critical',
      steps: [
        'If person has an EpiPen — use it immediately on outer thigh',
        'Call 112 immediately after using EpiPen',
        'Lay person flat — raise legs unless breathing is difficult',
        'If breathing is difficult — sit them upright',
        'Be prepared to give CPR if they lose consciousness',
        'A second EpiPen can be given after 5–15 minutes if needed',
      ],
      warnings: [
        'Anaphylaxis can be fatal within minutes',
        'EpiPen buys time — hospital treatment is still needed',
        'Do NOT give antihistamine as main treatment for anaphylaxis',
      ],
      callEmergency: [
        'Always — call 112 even after using EpiPen',
        'Signs: swollen throat, difficulty breathing, severe rash, collapse',
      ],
    ),

    'hello': FirstAidResponse(
      title: '🏥 Safe Connect First Aid Bot',
      severity: 'Info',
      steps: [
        'I can help with emergency first aid guidance.',
        'Type any of these topics:',
        '• Burns or scalds',
        '• Bleeding or wounds',
        '• CPR / cardiac arrest',
        '• Fractures or broken bones',
        '• Snake bite',
        '• Choking',
        '• Shock',
        '• Poisoning',
        '• Allergic reaction',
        '• Fever',
        '• Head injury',
        '• Drowning',
        '• Eye injury',
      ],
      warnings: [],
      callEmergency: [
        'For life-threatening emergencies always call 112 first',
      ],
    ),

    'fever': FirstAidResponse(
      title: '🌡️ Fever',
      severity: 'Medium',
      steps: [
        'Give paracetamol or ibuprofen as directed on packaging',
        'Keep the person cool — light clothing, cool room',
        'Encourage plenty of fluids to prevent dehydration',
        'Apply cool damp cloth to forehead, neck, armpits',
        'Do NOT wrap in blankets or warm clothing',
        'Monitor temperature every 30 minutes',
      ],
      warnings: [
        'Do NOT use cold or ice water — causes shivering which raises temp',
        'Do NOT give aspirin to children under 16',
      ],
      callEmergency: [
        'Temperature above 39.5°C (103°F)',
        'Fever with stiff neck, rash, confusion',
        'Child under 3 months with any fever',
        'Fever lasting more than 3 days',
      ],
    ),

    'head': FirstAidResponse(
      title: '🧠 Head Injury',
      severity: 'High',
      steps: [
        'Keep the person still — do not move unless in danger',
        'If unconscious and breathing — place in recovery position',
        'Apply gentle pressure to bleeding wounds with clean cloth',
        'Do NOT apply pressure if skull fracture is suspected',
        'Keep person awake and talking if conscious',
        'Monitor breathing, pulse, and consciousness level',
      ],
      warnings: [
        'Do NOT move person if spinal injury is possible',
        'Do NOT give pain medication that thins blood (aspirin)',
        'Do NOT leave person alone for 24 hours after head injury',
      ],
      callEmergency: [
        'Loss of consciousness even briefly',
        'Confusion, seizures, or repeated vomiting',
        'Clear fluid from nose or ears',
        'Unequal pupil sizes',
        'Severe headache',
      ],
    ),

    'drowning': FirstAidResponse(
      title: '🌊 Drowning',
      severity: 'Critical',
      steps: [
        'Get the person out of water — do NOT put yourself at risk',
        'Call 112 immediately',
        'If not breathing — start CPR immediately',
        'Give 5 rescue breaths first before chest compressions',
        'Continue CPR until help arrives',
        'Keep person warm — risk of hypothermia',
        'Even if person seems recovered — hospital check is needed',
      ],
      warnings: [
        'Secondary drowning can occur hours later',
        'Do NOT leave the person alone even if recovered',
        'Always get medical evaluation after drowning',
      ],
      callEmergency: [
        'Always — even if person seems fine',
        'Start CPR immediately if not breathing',
      ],
    ),
  };

  // ── Match query to a response ─────────────────────────────────────
  static FirstAidResponse? getResponse(String query) {
    final lower = query.toLowerCase();

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return _responses[entry.key];
        }
      }
    }

    return null;
  }

  // ── Get default/unknown response ──────────────────────────────────
  static FirstAidResponse getUnknownResponse(String query) {
    return FirstAidResponse(
      title: '❓ Topic Not Found',
      severity: 'Info',
      steps: [
        'I didn\'t understand "$query".',
        'Try asking about:',
        'burns, bleeding, CPR, fracture, snake bite,',
        'choking, shock, poisoning, allergy, fever,',
        'head injury, drowning, eye injury',
      ],
      warnings: [],
      callEmergency: ['For emergencies always call 112'],
    );
  }
}

// ── Response Model ────────────────────────────────────────────────
class FirstAidResponse {
  final String title;
  final String severity;
  final List<String> steps;
  final List<String> warnings;
  final List<String> callEmergency;

  const FirstAidResponse({
    required this.title,
    required this.severity,
    required this.steps,
    required this.warnings,
    required this.callEmergency,
  });
}