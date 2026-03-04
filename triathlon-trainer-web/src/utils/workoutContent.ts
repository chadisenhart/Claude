import { v4 as uuid } from 'uuid'
import type {
  Sport, TrainingPhase, WorkoutIntensity, ZoneBlock, CoachingTip, TechniqueCue
} from '../types'
import type { AthleteProfile } from '../types'

export interface WorkoutContent {
  title: string
  goal: string
  intensity: WorkoutIntensity
  distanceKm?: number
  zones: ZoneBlock[]
  warmup: string
  mainSet: string
  cooldown: string
  tips: CoachingTip[]
  techniqueCues: TechniqueCue[]
  postWorkoutGuidance: string
}

export function getWorkoutContent(
  sport: Sport,
  type: string,
  phase: TrainingPhase,
  experience: AthleteProfile['experienceLevel'],
  hours: number
): WorkoutContent {
  switch (sport) {
    case 'Swim': return swimContent(type, phase, experience, hours)
    case 'Bike': return bikeContent(type, phase, experience, hours)
    case 'Run':  return runContent(type, phase, experience, hours)
    case 'Brick': return brickContent(phase, experience, hours)
    default: return recoveryContent()
  }
}

// ─── Swim ──────────────────────────────────────────────────────────────────

function swimContent(type: string, _phase: TrainingPhase, experience: AthleteProfile['experienceLevel'], hours: number): WorkoutContent {
  const totalM = Math.round(hours * 60 * 25)
  const warmupM = Math.max(200, Math.round(totalM / 5))
  const cooldownM = Math.max(100, Math.round(totalM / 8))
  const mainM = totalM - warmupM - cooldownM

  if (type === 'intervals') {
    const repDist = experience === 'Beginner' ? 100 : 200
    const reps = Math.max(4, Math.round(mainM / repDist))
    return {
      title: 'Swim Threshold Intervals',
      goal: 'Push your CSS (Critical Swim Speed) and build lactate tolerance.',
      intensity: 'Threshold',
      distanceKm: totalM / 1000,
      zones: [
        { zone: 1, durationSeconds: hours * 0.25 * 3600, description: 'Warm-up' },
        { zone: 4, durationSeconds: hours * 0.55 * 3600, description: 'Threshold intervals' },
        { zone: 1, durationSeconds: hours * 0.20 * 3600, description: 'Cool-down' },
      ],
      warmup: `${warmupM}m easy. Then 4×25m build (start easy, finish fast). Shake out arms between reps. You need to feel warm before the hard work.`,
      mainSet: `${reps}×${repDist}m at threshold pace (RPE 7–8, sustainable hard effort). Rest = ${Math.round(repDist / 4)}s between reps.\n\nHold the same split on every rep — do NOT go out too fast. Last rep should feel like the hardest thing you've done today.\n\nIf your pace drops >5s/100m from rep 1 to rep ${reps}, take extra rest next session.`,
      cooldown: `${cooldownM}m easy. Focus on long strokes — your form breaks down under fatigue; this brings it back.`,
      tips: [
        tip('Pace Yourself', 'Start 2–3 seconds slower than you think you need to on rep 1. Consistency across all reps builds fitness better than one heroic first rep.', 'Main Set'),
        tip('Tight Turns', 'Drive your feet into the wall hard, streamline for 3–5m before your first stroke. Free speed.', 'Main Set'),
        tip('Post-Hard Session Recovery', 'Eat within 30 min: 3:1 carb:protein ratio. Chocolate milk, banana + yogurt, or a recovery shake.', 'Nutrition'),
      ],
      techniqueCues: [
        cue('Swim', 'Under fatigue, your kick drops. Quick, tight kicks from the hip — not big knee bends.', undefined, undefined, 'Bending at the knee too much, creating drag'),
        cue('Swim', 'Keep your head still while breathing. Only rotate your body — your head is an anchor.', undefined, undefined, 'Lifting your head to breathe, which sinks your hips'),
      ],
      postWorkoutGuidance: 'Note your average pace per 100m. This is your benchmark — each interval block should improve this number.',
    }
  }

  if (type === 'long') {
    return {
      title: 'Swim Endurance Build',
      goal: 'Build swim-specific aerobic base. Comfortable, efficient, continuous swimming.',
      intensity: 'Easy',
      distanceKm: totalM / 1000,
      zones: [
        { zone: 1, durationSeconds: hours * 0.20 * 3600, description: 'Warm-up' },
        { zone: 2, durationSeconds: hours * 0.65 * 3600, description: 'Steady aerobic' },
        { zone: 1, durationSeconds: hours * 0.15 * 3600, description: 'Cool-down' },
      ],
      warmup: `${warmupM}m easy with bilateral breathing — breathe every 3 strokes.`,
      mainSet: `${mainM}m continuous at easy/moderate pace — you should be able to hold a conversation.\n\nBreak into segments mentally: every 500m, do a quick form check:\n• Are your hips rotating?\n• Is your head neutral?\n• Are you exhaling fully underwater?`,
      cooldown: `${cooldownM}m backstroke. Open up your chest and shoulders.`,
      tips: [
        tip('Bilateral Breathing', 'Breathing every 3 strokes prevents muscle imbalance and prepares you for open water where waves come from any direction.', 'Main Set'),
        tip('Sighting for Open Water', 'Every 10–15 strokes, lift just your eyes above water (not your whole head). Crocodile sighting. Losing straight-line swimming costs 10–15% extra distance.', 'Main Set'),
      ],
      techniqueCues: [
        cue('Swim', '"Tall" in the water — imagine a string pulling the top of your head forward, lengthening your body line.', undefined, undefined, 'Sitting up in the water with head too high, creating massive drag'),
      ],
      postWorkoutGuidance: 'Long swims build your aerobic base. You should finish tired but not destroyed. If exhausted, slow down — the goal is volume, not intensity.',
    }
  }

  // Default: technique
  return {
    title: 'Swim Technique Session',
    goal: 'Build stroke efficiency and body position. Speed comes from technique, not effort.',
    intensity: 'Easy',
    distanceKm: totalM / 1000,
    zones: [
      { zone: 1, durationSeconds: hours * 0.30 * 3600, description: 'Warm-up' },
      { zone: 2, durationSeconds: hours * 0.50 * 3600, description: 'Drill sets' },
      { zone: 1, durationSeconds: hours * 0.20 * 3600, description: 'Cool-down' },
    ],
    warmup: `${warmupM}m easy freestyle. Focus on breathing rhythm: exhale fully underwater, inhale quickly to one side. Keep your head in neutral — eyes looking at the pool floor, not forward.`,
    mainSet: `4×50m catch-up drill (15s rest): One arm stays extended while the other completes its stroke. This forces you to feel the 'catch' — that crucial moment your hand grips the water.\n\n4×50m fingertip drag drill (15s rest): Drag your fingertips along the surface on recovery. Trains a high elbow recovery, reducing shoulder strain.\n\n${Math.max(0, mainM - 400)}m continuous easy freestyle applying drill focus. Count strokes per length and try to reduce by 1–2.`,
    cooldown: `${cooldownM}m backstroke or easy freestyle. Stretch arms above head on each stroke, feel the glide.`,
    tips: [
      tip('Rotate Your Hips', 'Your hips should rotate 45–60° with each stroke. Think of your body as a log rolling in the water — more rotation = longer reach.', 'Main Set'),
      tip('Exhale Underwater', 'Beginners hold their breath — this creates CO₂ buildup and anxiety. Exhale a steady stream of bubbles so you\'re ready to inhale when you rotate.', 'Before'),
      tip('Fuel & Hydrate', 'Even in the pool you sweat. Drink 500ml water before. A light snack 60–90 min before works well.', 'Nutrition'),
    ],
    techniqueCues: [
      cue('Swim', 'Reach long — enter your hand at 11 o\'clock and 1 o\'clock, not straight ahead. This widens your catch.', 'Alignment Entry', 'Exaggerate the wide entry, feel your shoulder open up', 'Crossing the centre-line, which causes zig-zagging'),
      cue('Swim', 'Keep your elbow HIGH during the pull phase — your forearm is the paddle, not just your hand.', 'High Elbow Catch', 'Pause at the catch position, feel forearm perpendicular to pool floor', 'Dropping the elbow and losing grip on water'),
    ],
    postWorkoutGuidance: 'Rate this session 1–10 for effort. If smooth and in control, hold that feeling in harder sessions. If breathing felt rushed, focus on your exhale next time.',
  }
}

// ─── Bike ──────────────────────────────────────────────────────────────────

function bikeContent(type: string, _phase: TrainingPhase, experience: AthleteProfile['experienceLevel'], hours: number): WorkoutContent {
  const distanceKm = hours * 28

  if (type === 'intervals') {
    const reps = experience === 'Beginner' ? 4 : 6
    const repMin = Math.round(hours * 60 * 0.5 / reps)
    return {
      title: 'Bike Threshold Intervals',
      goal: 'Push your FTP — the power you can sustain for 60 minutes. This is your race engine.',
      intensity: 'Threshold',
      distanceKm,
      zones: [
        { zone: 1, durationSeconds: hours * 0.25 * 3600, description: 'Warm-up' },
        { zone: 4, durationSeconds: hours * 0.50 * 3600, description: 'Threshold intervals' },
        { zone: 2, durationSeconds: hours * 0.25 * 3600, description: 'Cool-down' },
      ],
      warmup: `15 min easy spin. Include 3×30s pick-ups (zone 3) near end of warm-up to prime your legs. Cadence 85–95 rpm.`,
      mainSet: `${reps}×${repMin} min at threshold (RPE 7–8, ~95% of FTP if you have a power meter).\nRecovery = ${Math.max(2, Math.round(repMin / 3))} min easy spin between reps.\n\nHold a steady effort — don't surge. Last interval: give everything you have left.`,
      cooldown: '15 min easy spin. Flush the legs at 100+ rpm in easy gear.',
      tips: [
        tip('Aero Position Practice', 'If you race on a tri bike, spend part of each interval in aero position. Race-day power comes from training-specific positions.', 'Main Set'),
        tip('Smooth Power Output', 'Focus on consistent force throughout the stroke for better efficiency — no surges.', 'Main Set'),
        tip('Fuel During the Ride', 'For rides over 90 min: 60–90g carbs/hour starting at 30 min. Gels, chews, or real food all work.', 'Nutrition'),
      ],
      techniqueCues: [
        cue('Bike', 'Relax your upper body — uncurl your fingers, drop your shoulders, loosen your jaw. Tension wastes energy.', undefined, undefined, 'White-knuckling the bars under fatigue'),
        cue('Bike', 'Keep your knees tracking straight — they shouldn\'t splay out or pull in.', undefined, undefined, 'Knees flaring out due to hip flexibility limitations'),
      ],
      postWorkoutGuidance: 'Record your average power or RPE for each interval. Hard sessions need 48h easy training before the next hard effort.',
    }
  }

  if (type === 'long') {
    return {
      title: 'Long Endurance Ride',
      goal: 'Build fat-burning capacity, strengthen legs for race distance, practice race nutrition.',
      intensity: 'Moderate',
      distanceKm,
      zones: [
        { zone: 1, durationSeconds: hours * 0.15 * 3600, description: 'Warm-up' },
        { zone: 2, durationSeconds: hours * 0.65 * 3600, description: 'Aerobic endurance' },
        { zone: 3, durationSeconds: hours * 0.10 * 3600, description: 'Moderate surges' },
        { zone: 1, durationSeconds: hours * 0.10 * 3600, description: 'Cool-down' },
      ],
      warmup: 'First 20 min: gradually increase from zone 1 to zone 2. Let your body warm up properly.',
      mainSet: `Zone 2 endurance riding: comfortable but purposeful. You should speak in full sentences but not want to.\n\nEvery 30 min, do a 5 min zone 3 surge — this teaches your body to recover while still moving (race-like demands).\n\nPractice your nutrition: take something every 20–30 min. Aim for 60g+ carbs/hour on rides over 2 hours. Practice exactly what you'll use race day.`,
      cooldown: 'Last 15–20 min: easy zone 1, high cadence. Arrive home with some energy left.',
      tips: [
        tip('Race Nutrition Rehearsal', 'Long rides are where you test race nutrition. Try different gels, bars, real food. Find what your gut tolerates — race day is not the time to experiment.', 'Nutrition'),
        tip('Pacing Strategy', 'Start easier than you think you need to. Negative splitting (second half slightly faster) is more efficient than going out hard and fading.', 'Before'),
        tip('Position Variation', 'Change hand position every 15–20 min (hoods, drops, tops, aero). This prevents hotspots and keeps blood flowing to your hands.', 'Main Set'),
      ],
      techniqueCues: [
        cue('Bike', 'Hill climbing: shift to a gear that lets you maintain cadence (70–75 rpm min). Don\'t mash up hills.', undefined, undefined, 'Grinding big gears on climbs, spiking HR and burning matches'),
        cue('Bike', 'Descending: weight back, heels down, look through the corner, brake BEFORE the bend not in it.', undefined, undefined, 'Braking in corners — causes skidding and loss of control'),
      ],
      postWorkoutGuidance: 'This is your biggest aerobic investment each week. Refuel within 30 min with carbs + protein. Expect tired legs tomorrow.',
    }
  }

  // Easy
  return {
    title: 'Easy Recovery Ride',
    goal: 'Active recovery and aerobic maintenance. Spin your legs out — don\'t push.',
    intensity: 'Easy',
    distanceKm,
    zones: [{ zone: 1, durationSeconds: hours * 3600, description: 'Zone 1–2 easy' }],
    warmup: 'First 10 minutes: stay in an easy gear, high cadence (90+ rpm). Don\'t worry about speed.',
    mainSet: 'Zone 1–2 riding at 90–100 rpm cadence. Keep effort LOW. This is a recovery ride — if you feel the urge to push, resist it.',
    cooldown: 'Last 5 minutes: even easier. Spin down, pedal smooth circles.',
    tips: [
      tip('Cadence Over Power', 'High cadence (90–100 rpm) in easy gears reduces muscle fatigue while keeping cardiovascular adaptation. Think spinning, not grinding.', 'Main Set'),
    ],
    techniqueCues: [
      cue('Bike', 'Pedal full circles — push down, pull back at the bottom, scrape mud from your shoe.', 'Single Leg Drill', 'Unclip one foot, pedal with one leg for 30s, feel the dead spots', 'Only pushing down — this wastes the pull-through phase'),
    ],
    postWorkoutGuidance: 'Easy rides don\'t need aggressive recovery. Normal meal and hydration is fine.',
  }
}

// ─── Run ───────────────────────────────────────────────────────────────────

function runContent(type: string, _phase: TrainingPhase, experience: AthleteProfile['experienceLevel'], hours: number): WorkoutContent {
  const distanceKm = hours * 10

  if (type === 'tempo') {
    return {
      title: 'Tempo Run',
      goal: 'Push your lactate threshold — the pace you can sustain for about an hour. This is your triathlon run pace.',
      intensity: 'Threshold',
      distanceKm,
      zones: [
        { zone: 1, durationSeconds: hours * 0.20 * 3600, description: 'Warm-up' },
        { zone: 3, durationSeconds: hours * 0.60 * 3600, description: 'Tempo' },
        { zone: 1, durationSeconds: hours * 0.20 * 3600, description: 'Cool-down' },
      ],
      warmup: '10–15 min easy jog. Then 4×20s strides at 5km pace with 40s walk recovery. Strides prime your neuromuscular system.',
      mainSet: 'Tempo running at RPE 6–7: "comfortably uncomfortable". You can say 3–4 words but not hold a conversation. Approximately your 10km race pace.\n\nHold even splits — don\'t go too fast in the first half.',
      cooldown: '10 min easy jog. Let your HR come down gradually. Static stretches.',
      tips: [
        tip('Know Your Tempo Pace', 'If unknown, use your recent 10km race time + 15 sec/km. Or 80–88% max HR. Should feel hard but sustainable.', 'Before'),
        tip('Running Economy Focus', 'Under tempo effort, tighten your core slightly, keep arms efficient, maintain forward lean.', 'Main Set'),
      ],
      techniqueCues: [
        cue('Run', 'Forward lean from the ankles (not waist) of 5–10°. This uses gravity to help you move forward.', undefined, undefined, 'Sitting back on heels, which acts as a brake every step'),
        cue('Run', 'Quick feet: focus on picking your feet up quickly rather than pushing off hard.', undefined, undefined, 'Heavy heel striking with long ground contact time'),
      ],
      postWorkoutGuidance: 'Record your tempo pace. Over the training block this pace should improve by 10–30 sec/km.',
    }
  }

  if (type === 'intervals') {
    const reps = experience === 'Beginner' ? 4 : 6
    return {
      title: 'Run Intervals (VO2 Max)',
      goal: 'Develop your aerobic capacity ceiling. These are the hardest run sessions — biggest fitness gains.',
      intensity: 'VO2 Max',
      distanceKm,
      zones: [
        { zone: 1, durationSeconds: hours * 0.25 * 3600, description: 'Warm-up' },
        { zone: 5, durationSeconds: hours * 0.45 * 3600, description: 'VO2 max intervals' },
        { zone: 1, durationSeconds: hours * 0.30 * 3600, description: 'Cool-down' },
      ],
      warmup: '15 min easy run. Then 4×15s strides at near-sprint pace (90s recovery). You must be properly warm before intervals.',
      mainSet: `${reps}×3 min at hard effort (RPE 8.5–9): faster than 5km race pace but controlled enough to maintain form.\nRecovery = 3 min easy jog between reps.\n\nYou should be breathing very hard. You should dread the next rep. If reps feel easy, you\'re going too slow. If you can\'t finish, you started too fast.`,
      cooldown: '15 min easy jog. Walk last 5 min. Stretch thoroughly.',
      tips: [
        tip('Respect the Recovery Interval', 'Active recovery (slow jog) between intervals flushes lactate better than standing still. Keep moving.', 'Main Set'),
        tip('VO2 Max Frequency', 'Once per week maximum. These sessions stress your cardiovascular system maximally. Too many causes breakdown, not improvement.', 'Before'),
      ],
      techniqueCues: [
        cue('Run', 'At high speed: tall posture, drive elbows back (not forward), foot lands under your hip not in front of it.', undefined, undefined, 'Reaching forward with the leg — creates a braking force'),
        cue('Run', 'Breathe in rhythm: 2 steps in, 2 steps out at high intensity. Rhythmic breathing reduces side stitches.', undefined, undefined, 'Irregular breathing causing oxygen supply/demand mismatch'),
      ],
      postWorkoutGuidance: 'Rate each interval 1–10. If later intervals are much harder than early ones, note it — slow your early-interval pacing next session.',
    }
  }

  if (type === 'long') {
    return {
      title: 'Long Run',
      goal: 'Build aerobic base and mental toughness for race distance running.',
      intensity: 'Easy',
      distanceKm,
      zones: [
        { zone: 1, durationSeconds: hours * 0.15 * 3600, description: 'Warm-up' },
        { zone: 2, durationSeconds: hours * 0.75 * 3600, description: 'Steady long run' },
        { zone: 1, durationSeconds: hours * 0.10 * 3600, description: 'Cool-down' },
      ],
      warmup: '5–10 min walk, then ease into running. First 10 min should feel almost too easy.',
      mainSet: 'Long easy run at zone 2. If training for 70.3 or Ironman, practice run-walk strategy: run 9 min, walk 1 min.\n\nLast 15–20% of run: if legs have it, push to moderate zone 3 pace. This "fast finish" simulates running tired at race end.',
      cooldown: 'Walk 5–10 min. Foam roll calves, IT band, quads.',
      tips: [
        tip('Walk Breaks Are Racing Strategy', 'Athletes who use walk-run strategies often finish the same or faster overall. Don\'t see walking as failure.', 'Main Set'),
        tip('Long Run Nutrition', 'Take a gel or 30g carbs every 45 min on runs over 75 min. Your gut needs training too.', 'Nutrition'),
        tip('Mental Strategy', 'Break it into thirds: first third hold back, second settle in, last third give what you have.', 'Main Set'),
      ],
      techniqueCues: [
        cue('Run', 'As you fatigue: head drops, arms cross body, hips drop back. Every 10 min do a form check: tall posture, light arms, quick feet.', undefined, undefined, 'Allowing form to collapse — reinforces bad movement patterns'),
        cue('Run', 'Downhills: lean forward, small steps, feet under hips. Don\'t brake with your heels.', undefined, undefined, 'Heel braking on descents, destroying quads'),
      ],
      postWorkoutGuidance: 'Long runs take 24–48h to recover from. Eat within 30 min (high carb + protein). Sleep well tonight.',
    }
  }

  // Easy
  return {
    title: 'Easy Aerobic Run',
    goal: 'Build running economy and aerobic base. Conversational pace only.',
    intensity: 'Easy',
    distanceKm,
    zones: [
      { zone: 1, durationSeconds: hours * 0.15 * 3600, description: 'Warm-up' },
      { zone: 2, durationSeconds: hours * 0.75 * 3600, description: 'Easy aerobic' },
      { zone: 1, durationSeconds: hours * 0.10 * 3600, description: 'Cool-down' },
    ],
    warmup: '5 min brisk walk, then 5 min very easy jog. Include dynamic stretches: leg swings, hip circles, high knees (easy).',
    mainSet: 'Easy zone 2 running. Use the "talk test": you should be able to speak in full sentences.\n\nHeart rate 60–70% max. If you can\'t talk, slow down — no ego on easy days.\n\nCheck in every 10 min: relaxed shoulders? Slight forward lean? Feet landing under hips?',
    cooldown: '5 min easy walk. Static stretches: calves, quads, hamstrings, hip flexors (30s each).',
    tips: [
      tip('Easy Means Easy', 'Most triathletes run too fast on easy days. These should feel almost embarrassingly slow. The aerobic adaptation still happens — trust the process.', 'Main Set'),
      tip('Fueling for Easy Runs', 'Under 60 min: water is enough. Over 60 min: start carbs at 40–45 min.', 'Nutrition'),
    ],
    techniqueCues: [
      cue('Run', 'Cadence: aim for 170–180 steps per minute. High cadence = shorter ground contact = less impact on joints.', 'Cadence Metronome', 'Use a metronome app at 175–180 bpm, match footstrike to the beat', 'Over-striding — landing heel first in front of your centre of mass'),
      cue('Run', 'Arms drive your legs. Elbows at 90°, swing from shoulder (not across chest), hands relaxed.', undefined, undefined, 'Arms crossing the body centreline, causing rotational waste'),
    ],
    postWorkoutGuidance: 'Log how your legs felt. If easy runs feel like hard runs, you need more recovery.',
  }
}

// ─── Brick ─────────────────────────────────────────────────────────────────

function brickContent(_phase: TrainingPhase, _experience: AthleteProfile['experienceLevel'], hours: number): WorkoutContent {
  const bikeH = hours * 0.75
  const runH = hours * 0.25
  const bikeKm = Math.round(bikeH * 28)
  const runKm = Math.round(runH * 10 * 10) / 10

  return {
    title: 'Bike → Run Brick',
    goal: 'Train your legs to switch from cycling to running. The only way to make this easier is to practice it. This is the most triathlon-specific training you can do.',
    intensity: 'Moderate',
    distanceKm: bikeKm + runKm,
    zones: [
      { zone: 1, durationSeconds: bikeH * 0.15 * 3600, description: 'Bike warm-up' },
      { zone: 2, durationSeconds: bikeH * 0.65 * 3600, description: 'Bike main' },
      { zone: 3, durationSeconds: bikeH * 0.20 * 3600, description: 'Bike finish strong' },
      { zone: 3, durationSeconds: runH * 3600, description: 'Run off bike' },
    ],
    warmup: 'Start bike easy for 10–15 min. Gradually increase to target pace. Eat/drink at 20 min into bike.',
    mainSet: `BIKE (${bikeKm}km): Ride at moderate effort (zone 2–3). Last 10 min: increase to zone 3 — this raises your HR so you begin the run already working.\n\nTRANSITION (T2): Rack bike, remove helmet, switch to run shoes. Practice fast lace locks. You want this under 60 seconds.\n\nRUN (${runKm}km): Start immediately — don't stop. First 5 min will feel awful: legs heavy, gait strange. THIS IS NORMAL. Push through it. By min 5–8, your running muscles activate and it smooths out. Run at moderate effort (zone 2–3).`,
    cooldown: 'Walk 5 min after run. Stretch both cycling and running muscles: hip flexors especially.',
    tips: [
      tip('The Brick Feeling', 'That heavy wooden-leg feeling in the first few minutes is "brick legs". It\'s caused by muscle fiber recruitment shifting from cycling to running. It always gets easier with training.', 'Before'),
      tip('Fast Transitions Win Races', 'T2 time is "free speed". Lay out run gear in exactly the same spot each time. Elastic laces save 10–15 seconds without practice.', 'Before'),
      tip('Bike Nutrition Timing', 'Don\'t eat anything in the last 15–20 min of the bike — avoids stomach sloshing on the run.', 'Nutrition'),
    ],
    techniqueCues: [
      cue('Run', 'Off the bike, your running stride will be shorter than normal — this is correct. Don\'t force your normal stride length immediately. Let it come back over 5–10 min.', undefined, undefined, 'Forcing normal stride immediately, causing tripping or hip/knee strain'),
      cue('Bike', 'Last 2–3 min of bike: spin in easier gear at 100+ rpm. Flushes lactic acid and begins recruiting running muscles before you dismount.', undefined, undefined, 'Grinding a hard gear to the finish, arriving at T2 with locked-up legs'),
    ],
    postWorkoutGuidance: 'Note how long brick legs lasted (typically 3–8 min). This duration should decrease as the season progresses.',
  }
}

// ─── Recovery ─────────────────────────────────────────────────────────────

function recoveryContent(): WorkoutContent {
  return {
    title: 'Rest & Recovery',
    goal: 'Your body gets stronger during recovery, not during training.',
    intensity: 'Recovery',
    zones: [],
    warmup: '',
    mainSet: 'Complete rest, or gentle 20–30 min walk. No structured exercise.',
    cooldown: '',
    tips: [
      tip('Sleep is Training', '70–80% of training adaptations happen during deep sleep. Prioritise 7–9 hours.', 'Before'),
      tip('Foam Rolling & Mobility', '15–20 min foam rolling on rest days accelerates recovery. Focus on: calves, IT band, hip flexors, thoracic spine.', 'After'),
    ],
    techniqueCues: [],
    postWorkoutGuidance: 'Recovery is where the magic happens. Trust the process.',
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

function tip(title: string, detail: string, timing: CoachingTip['timing']): CoachingTip {
  return { id: uuid(), title, detail, timing }
}

function cue(
  sport: Sport,
  cueText: string,
  drillName?: string,
  drillDescription?: string,
  commonMistake?: string
): TechniqueCue {
  return { id: uuid(), sport, cue: cueText, drillName, drillDescription, commonMistake }
}
