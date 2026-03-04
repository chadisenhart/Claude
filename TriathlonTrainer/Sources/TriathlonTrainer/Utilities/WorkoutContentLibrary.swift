import Foundation

/// Library of workout content: instructions, coaching tips, and technique cues
/// for each sport, workout type, and training phase.
struct WorkoutContentLibrary {

    struct WorkoutContent {
        var title: String
        var goal: String
        var workoutType: WorkoutType
        var intensity: Intensity
        var distanceKm: Double?
        var zones: [TrainingZoneBlock]
        var warmup: String
        var mainSet: String
        var cooldown: String
        var tips: [CoachingTip]
        var techniqueCues: [TechniqueCue]
        var postWorkoutGuidance: String
    }

    static func content(
        for sport: Sport,
        type: WorkoutAssignmentType,
        phase: TrainingPhase,
        experience: ExperienceLevel,
        durationHours: Double
    ) -> WorkoutContent {
        switch sport {
        case .swim:
            return swimContent(type: type, phase: phase, experience: experience, durationHours: durationHours)
        case .bike:
            return bikeContent(type: type, phase: phase, experience: experience, durationHours: durationHours)
        case .run:
            return runContent(type: type, phase: phase, experience: experience, durationHours: durationHours)
        case .brick:
            return brickContent(phase: phase, experience: experience, durationHours: durationHours)
        default:
            return recoveryContent()
        }
    }

    // MARK: - Swim Content

    static func swimContent(
        type: WorkoutAssignmentType,
        phase: TrainingPhase,
        experience: ExperienceLevel,
        durationHours: Double
    ) -> WorkoutContent {
        let totalMeters = Int(durationHours * 60 * 25) // ~25m/min for moderate effort
        let warmupMeters = max(200, totalMeters / 5)
        let cooldownMeters = max(100, totalMeters / 8)
        let mainMeters = totalMeters - warmupMeters - cooldownMeters

        switch type {
        case .technique, .easy:
            return WorkoutContent(
                title: "Swim Technique Session",
                goal: "Build stroke efficiency and body position. Nail the fundamentals — speed comes from technique, not effort.",
                workoutType: .swimTechnique,
                intensity: .easy,
                distanceKm: Double(totalMeters) / 1000,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.3 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.5 * 3600, description: "Drill sets"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.2 * 3600, description: "Cool-down")
                ],
                warmup: """
                    \(warmupMeters)m easy freestyle. Focus on breathing rhythm: exhale fully underwater, \
                    inhale quickly to one side. Keep your head in neutral position — eyes looking at the \
                    bottom of the pool, not forward. Kick gently from the hips, not knees.
                    """,
                mainSet: """
                    4 × 50m catch-up drill (15s rest): One arm stays extended while the other completes its stroke. \
                    This forces you to feel the 'catch' — that crucial moment your hand grips the water.

                    4 × 50m fingertip drag drill (15s rest): Drag your fingertips along the surface on recovery. \
                    Trains a high elbow recovery, reducing shoulder strain over long distances.

                    \(mainMeters - 400)m continuous easy freestyle, applying drill focus. Aim for \
                    long, smooth strokes — count your strokes per length and try to reduce by 1-2.
                    """,
                cooldown: "\(cooldownMeters)m backstroke or easy freestyle. Stretch arms above head on each stroke, feel the glide.",
                tips: [
                    CoachingTip(title: "Rotate Your Hips", detail: "Your hips should rotate 45-60° with each stroke. This lets you reach further and pull more water. Think of your body as a log rolling in the water.", timing: .duringMainSet),
                    CoachingTip(title: "Exhale Underwater", detail: "Beginners hold their breath — this creates CO2 buildup and anxiety. Exhale a steady stream of bubbles when your face is in the water so you're ready to inhale when you rotate.", timing: .preWorkout),
                    CoachingTip(title: "Fuel & Hydrate", detail: "Even in the pool you sweat. Drink 500ml water before and have a bottle on deck. A light snack 60-90 min before works well.", timing: .nutrition),
                    CoachingTip(title: "Post-Swim Stretch", detail: "Swim works your lats and pecs hard. Stretch with your arm across your chest and a doorway chest stretch after.", timing: .postWorkout)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .swim, cue: "Reach long — enter your hand at 11 o'clock and 1 o'clock, not straight ahead. This widens your catch.", drillName: "Alignment Entry", drillDescription: "Exaggerate the wide entry, feel your shoulder open up", commonMistake: "Crossing the centre-line, which causes zig-zagging"),
                    TechniqueCue(sport: .swim, cue: "Keep your elbow high during the pull phase — your forearm is the paddle, not just your hand.", drillName: "High Elbow Catch", drillDescription: "Pause at the catch position, feel forearm perpendicular to pool floor", commonMistake: "Dropping the elbow and losing the grip on water")
                ],
                postWorkoutGuidance: "Rate this session 1-10 for effort. If you felt smooth and in control, great — hold that same feeling in harder sessions. If breathing felt rushed, focus on your exhale next time."
            )

        case .intervals:
            let repDistance = experience == .beginner ? 100 : 200
            let reps = max(4, mainMeters / repDistance)
            return WorkoutContent(
                title: "Swim Threshold Intervals",
                goal: "Push your swim CSS (Critical Swim Speed) and build lactate tolerance. These hurt — that's the point.",
                workoutType: .swimThreshold,
                intensity: .threshold,
                distanceKm: Double(totalMeters) / 1000,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.25 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 4, durationSeconds: durationHours * 0.55 * 3600, description: "Threshold intervals"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.2 * 3600, description: "Cool-down")
                ],
                warmup: """
                    \(warmupMeters)m easy. Then 4×25m build (start easy, finish fast). \
                    Shake out arms between reps. You need to feel warm before the hard work.
                    """,
                mainSet: """
                    \(reps)×\(repDistance)m at threshold pace (RPE 7-8, sustainable hard effort). \
                    Rest = \(repDistance / 4)s between reps. Hold the same split on every rep — \
                    do not go out too fast. Last rep should feel like the hardest thing you've done today.

                    If your pace drops >5s/100m from rep 1 to rep \(reps), take extra rest next session.
                    """,
                cooldown: "\(cooldownMeters)m easy. Focus on long strokes — your form breaks down under fatigue, this brings it back.",
                tips: [
                    CoachingTip(title: "Pace Yourself", detail: "Start 2-3 seconds slower than you think you need to on rep 1. Consistency across all reps builds fitness better than one heroic first rep and dying on the rest.", timing: .duringMainSet),
                    CoachingTip(title: "Tight Turns", detail: "In a triathlon you'll turn buoys, not walls — but fast pool turns = less wasted time. Drive your feet into the wall hard, streamline off the wall for 3-5m before your first stroke.", timing: .duringMainSet),
                    CoachingTip(title: "Post-Hard Session Recovery", detail: "Eat within 30 minutes: 3:1 carb:protein ratio. Chocolate milk, banana + yogurt, or a proper recovery shake. This is when your body is most receptive to rebuilding.", timing: .nutrition)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .swim, cue: "Under fatigue, your kick drops. Remind yourself: quick, tight kicks from the hip — not big knee bends.", commonMistake: "Bending at the knee too much, which creates drag"),
                    TechniqueCue(sport: .swim, cue: "Keep your head still while breathing. Only rotate your body — your head is an anchor, not a baseball.", commonMistake: "Lifting your head to breathe, which sinks your hips")
                ],
                postWorkoutGuidance: "Note your average pace per 100m. This is your benchmark — each interval block should see this number improve over the training cycle."
            )

        case .longEndurance:
            return WorkoutContent(
                title: "Swim Endurance Build",
                goal: "Build swim-specific aerobic base. Comfortable, efficient, continuous swimming.",
                workoutType: .swimEndurance,
                intensity: .easy,
                distanceKm: Double(totalMeters) / 1000,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.2 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.65 * 3600, description: "Steady aerobic"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.15 * 3600, description: "Cool-down")
                ],
                warmup: "\(warmupMeters)m easy with focus on bilateral breathing — breathe every 3 strokes.",
                mainSet: """
                    \(mainMeters)m continuous at easy/moderate pace — you should be able to hold a conversation. \
                    Break into segments mentally: every 500m, do a quick form check. \
                    Are your hips rotating? Is your head neutral? Are you exhaling fully?
                    """,
                cooldown: "\(cooldownMeters)m backstroke. Open up your chest and shoulders.",
                tips: [
                    CoachingTip(title: "Bilateral Breathing", detail: "Breathing every 3 strokes (left side, then right side) prevents muscle imbalance and makes you more adaptable in open water where waves come from any direction.", timing: .duringMainSet),
                    CoachingTip(title: "Sighting for Open Water", detail: "Every 10-15 strokes, do a 'crocodile' sight: lift just your eyes above water (not your whole head) to see where you're going. Losing straight-line swimming in a race costs 10-15% extra distance.", timing: .duringMainSet)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .swim, cue: "'Tall' in the water — imagine a string pulling the top of your head forward, lengthening your body line.", commonMistake: "Sitting up in the water with head too high, creating massive drag")
                ],
                postWorkoutGuidance: "Long swims build your aerobic base. You should finish feeling tired but not destroyed. If you're exhausted, slow down — the goal is volume, not intensity."
            )

        default:
            return swimContent(type: .easy, phase: phase, experience: experience, durationHours: durationHours)
        }
    }

    // MARK: - Bike Content

    static func bikeContent(
        type: WorkoutAssignmentType,
        phase: TrainingPhase,
        experience: ExperienceLevel,
        durationHours: Double
    ) -> WorkoutContent {
        let distanceKm = durationHours * 28 // ~28 km/h average

        switch type {
        case .easy, .recovery:
            return WorkoutContent(
                title: "Easy Recovery Ride",
                goal: "Active recovery and aerobic maintenance. Spin your legs out, don't push.",
                workoutType: .bikeEasy,
                intensity: .easy,
                distanceKm: distanceKm,
                zones: [TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 3600, description: "Zone 1-2 easy")],
                warmup: "First 10 minutes: stay in an easy gear, high cadence (90+ rpm). Don't worry about speed.",
                mainSet: """
                    Zone 1-2 riding at 90-100 rpm cadence. Keep your power/effort LOW. \
                    This is a recovery ride — if you feel the urge to push, resist it. \
                    The aerobic benefit comes from the movement, not the effort.
                    """,
                cooldown: "Last 5 minutes: even easier. Spin down, pedal squares to smooth circles.",
                tips: [
                    CoachingTip(title: "Cadence Over Power", detail: "High cadence (90-100 rpm) in easy gears reduces muscle fatigue while keeping cardiovascular adaptation. Think spinning, not grinding.", timing: .duringMainSet),
                    CoachingTip(title: "Check Your Fit", detail: "Knee should be slightly bent at bottom of pedal stroke (25-35° angle). Too low = knee pain. Too high = loss of power. Get a proper bike fit if you haven't.", timing: .preWorkout)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .bike, cue: "Pedal full circles — push down and pull back at the bottom, scrape mud from your shoe.", drillName: "Single Leg Drill", drillDescription: "Unclip one foot, pedal with one leg for 30s, feel the dead spots in your stroke", commonMistake: "Only pushing down — this wastes the pull-through phase")
                ],
                postWorkoutGuidance: "Easy rides don't need aggressive recovery. A normal meal and hydration is fine."
            )

        case .intervals:
            let intervalMinutes = Int(durationHours * 60 * 0.5)
            let reps = experience == .beginner ? 4 : 6
            let repMinutes = intervalMinutes / reps
            return WorkoutContent(
                title: "Bike Threshold Intervals",
                goal: "Push your FTP (Functional Threshold Power) — the power you can sustain for 60 minutes. This is your race engine.",
                workoutType: .bikeIntervals,
                intensity: .threshold,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.25 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 4, durationSeconds: durationHours * 0.5 * 3600, description: "Threshold intervals"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.25 * 3600, description: "Cool-down")
                ],
                warmup: """
                    15 min easy spin. Include 3×30s pick-ups (zone 3) near end of warm-up \
                    to prime your legs. Cadence should feel natural at 85-95 rpm.
                    """,
                mainSet: """
                    \(reps)×\(repMinutes) min at threshold (RPE 7-8, or ~95% of FTP if you have a power meter). \
                    Recovery = \(max(2, repMinutes / 3)) min easy spin between reps.

                    Hold a steady effort — don't surge. Your cadence can drop slightly to 80-85 rpm as you fatigue. \
                    Last interval: give everything you have left.
                    """,
                cooldown: "15 min easy spin. Flush the legs at 100+ rpm in easy gear.",
                tips: [
                    CoachingTip(title: "Aero Position Practice", detail: "If you race on a tri bike or in aero bars, spend part of each interval in aero position. Race-day power comes from training-specific positions — aero is a skill.", timing: .duringMainSet),
                    CoachingTip(title: "Smooth Power Output", detail: "Power meters show you pedaling 'squares' — bursts of power then dead spots. Focus on consistent force throughout the stroke for better efficiency.", timing: .duringMainSet),
                    CoachingTip(title: "Fuel During the Ride", detail: "For rides over 90 min, take 60-90g carbs per hour. Start fueling at 30 minutes — don't wait until you feel empty. Gels, chews, or real food all work.", timing: .nutrition)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .bike, cue: "Relax your upper body — uncurl your fingers, drop your shoulders, loosen your jaw. Tension in the upper body wastes energy.", commonMistake: "White-knuckling the bars under fatigue, wasting energy in your arms and shoulders"),
                    TechniqueCue(sport: .bike, cue: "Keep your knees tracking straight — they shouldn't splay out or pull in. Knee alignment affects power transfer and injury risk.", commonMistake: "Knees flaring out due to hip flexibility limitations")
                ],
                postWorkoutGuidance: "Record your average power or RPE for each interval. This data drives your adaptation plan. Hard sessions need 48h of easy training before the next hard effort."
            )

        case .longEndurance:
            return WorkoutContent(
                title: "Long Endurance Ride",
                goal: "Build fat-burning capacity, strengthen legs for race distance, and practice race nutrition strategy.",
                workoutType: .bikeEndurance,
                intensity: .moderate,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.15 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.65 * 3600, description: "Aerobic endurance"),
                    TrainingZoneBlock(zone: 3, durationSeconds: durationHours * 0.1 * 3600, description: "Moderate surges"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.1 * 3600, description: "Cool-down")
                ],
                warmup: "First 20 min: gradually increase from zone 1 to zone 2. Let your body warm up properly.",
                mainSet: """
                    Zone 2 endurance riding: comfortable but purposeful. You should be able to speak in \
                    full sentences but shouldn't want to. Every 30 min, do a 5 min zone 3 surge — \
                    this teaches your body to recover while still moving forward (race-like demands).

                    Practice your nutrition: take something every 20-30 min. Aim for 60g+ carbs/hour \
                    on rides over 2 hours. Practice exactly what you'll use on race day.
                    """,
                cooldown: "Last 15-20 min: easy zone 1, high cadence. Arrive home with some energy left.",
                tips: [
                    CoachingTip(title: "Race Nutrition Rehearsal", detail: "Long rides are where you test your race nutrition. Try different gels, bars, or real food. Find what your gut tolerates. Race day is not the time to experiment.", timing: .nutrition),
                    CoachingTip(title: "Pacing Strategy", detail: "Start easier than you think you need to. 'Negative splitting' (riding the second half slightly faster) is more efficient than going out hard and fading.", timing: .preWorkout),
                    CoachingTip(title: "Position Variation", detail: "On long rides, change your hand position every 15-20 min (hoods, drops, tops, aero). This prevents hotspots and keeps blood flowing to your hands.", timing: .duringMainSet)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .bike, cue: "Hill climbing: shift to a gear that lets you maintain cadence (70-75 rpm min). Don't mash up hills — it spikes your HR and burns matches you need later.", commonMistake: "Grinding big gears on climbs, creating lactate spikes that take 10+ min to recover from"),
                    TechniqueCue(sport: .bike, cue: "Descending: keep your weight back, heels down, look through the corner, brake before the bend not in it.", commonMistake: "Braking in corners — this causes skidding and loss of control")
                ],
                postWorkoutGuidance: "This is your biggest aerobic investment each week. Refuel within 30 min with carbs + protein. Expect legs to be tired tomorrow — that's the adaptation signal."
            )

        default:
            return bikeContent(type: .easy, phase: phase, experience: experience, durationHours: durationHours)
        }
    }

    // MARK: - Run Content

    static func runContent(
        type: WorkoutAssignmentType,
        phase: TrainingPhase,
        experience: ExperienceLevel,
        durationHours: Double
    ) -> WorkoutContent {
        let distanceKm = durationHours * 10 // ~10 km/h easy pace

        switch type {
        case .easy, .recovery:
            return WorkoutContent(
                title: "Easy Aerobic Run",
                goal: "Build running economy and aerobic base. Conversational pace only. If in doubt, go slower.",
                workoutType: .runEasy,
                intensity: .easy,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.15 * 3600, description: "Warm-up walk/jog"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.75 * 3600, description: "Easy aerobic"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.1 * 3600, description: "Cool-down walk")
                ],
                warmup: "5 min brisk walk, then 5 min very easy jog. Include dynamic stretches: leg swings, hip circles, high knees (easy).",
                mainSet: """
                    Easy zone 2 running. Use the 'talk test': you should be able to speak in full sentences. \
                    Heart rate should be 60-70% max. If you can't talk, slow down — no ego on easy days.

                    Check in every 10 min: relaxed shoulders? Slight forward lean from ankles? \
                    Feet landing under hips (not in front)?
                    """,
                cooldown: "5 min easy walk. Static stretches: calves, quads, hamstrings, hip flexors (30s each).",
                tips: [
                    CoachingTip(title: "Easy Means Easy", detail: "Most triathletes run too fast on easy days and not hard enough on hard days. Easy runs should feel almost embarrassingly slow. The aerobic adaptation still happens — trust the process.", timing: .duringMainSet),
                    CoachingTip(title: "Running off the Bike", detail: "Tri-specific tip: your legs will feel like concrete after cycling. Easy runs after bikes (brick training) teach your body this transition. Today is practice for that.", timing: .preWorkout),
                    CoachingTip(title: "Fueling for Easy Runs", detail: "Under 60 min: water is enough. Over 60 min: start with carbs at 40-45 min. Don't wait until you're empty.", timing: .nutrition)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .run, cue: "Cadence: aim for 170-180 steps per minute. High cadence = shorter ground contact time = less impact on joints.", drillName: "Cadence Metronome", drillDescription: "Use a metronome app at 175-180 bpm, match your footstrike to the beat", commonMistake: "Over-striding — landing heel first in front of your centre of mass"),
                    TechniqueCue(sport: .run, cue: "Arms drive your legs. Keep elbows at 90°, swing from the shoulder (not across your chest), hands relaxed as if holding crisps without breaking them.", commonMistake: "Arms crossing the body's centreline, causing rotational waste")
                ],
                postWorkoutGuidance: "Log how your legs felt. If easy runs feel like hard runs, you need more recovery. If they feel genuinely easy, your fitness is building nicely."
            )

        case .tempo:
            return WorkoutContent(
                title: "Tempo Run",
                goal: "Push your lactate threshold — the pace you can sustain for about an hour. This is your triathlon run pace.",
                workoutType: .runTempo,
                intensity: .threshold,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.2 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 3, durationSeconds: durationHours * 0.6 * 3600, description: "Tempo"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.2 * 3600, description: "Cool-down")
                ],
                warmup: """
                    10-15 min easy jog. Then 4×20s strides at 5km pace with 40s walk recovery. \
                    Strides prime your neuromuscular system for fast running.
                    """,
                mainSet: """
                    Tempo running at RPE 6-7: 'comfortably uncomfortable'. You can say 3-4 words \
                    but not hold a conversation. This pace is approximately your 10km race pace, \
                    or about 10-15 sec/km slower than 5km pace.

                    Hold even splits — don't go too fast in the first half. The goal is consistent \
                    effort throughout.
                    """,
                cooldown: "10 min easy jog. Let your HR come down gradually. Static stretches.",
                tips: [
                    CoachingTip(title: "Know Your Tempo Pace", detail: "If you don't know your threshold pace, use your recent 10km race time + 15 sec/km. Or use heart rate: 80-88% max HR. This pace should feel hard but sustainable.", timing: .preWorkout),
                    CoachingTip(title: "Running Economy Focus", detail: "Under tempo effort, small inefficiencies matter. Tighten your core slightly, keep your arms efficient, maintain forward lean. Running economy saves energy for the finish.", timing: .duringMainSet)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .run, cue: "Forward lean from the ankles (not waist) of 5-10°. This uses gravity to help you move forward instead of fighting it.", commonMistake: "Sitting back on heels, which acts as a brake every step"),
                    TechniqueCue(sport: .run, cue: "Quick feet: focus on picking your feet up quickly rather than pushing off hard. Less ground contact = less brake force.", commonMistake: "Heavy heel striking with long ground contact time")
                ],
                postWorkoutGuidance: "Record your tempo pace. Over the training block, this pace should improve by 10-30 sec/km. That's your running fitness progressing."
            )

        case .longEndurance:
            return WorkoutContent(
                title: "Long Run",
                goal: "Build your aerobic base and mental toughness for race distance running. The cornerstone of triathlon run training.",
                workoutType: .runLong,
                intensity: .easy,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.15 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 2, durationSeconds: durationHours * 0.75 * 3600, description: "Steady long run"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.1 * 3600, description: "Cool-down")
                ],
                warmup: "5-10 min walk, then ease into running. Don't rush the warm-up on long runs — the first 10 min should feel almost too easy.",
                mainSet: """
                    Long easy run at zone 2 — same principle as easy runs but extended duration. \
                    If you're training for a half or full Ironman: practice your run-walk strategy. \
                    Jeff Galloway method (run 9 min, walk 1 min) lets you go further with less breakdown.

                    Last 15-20% of the run: if legs have it, push to moderate zone 3 pace. \
                    This 'fast finish' simulates running tired at the end of a race.
                    """,
                cooldown: "Walk 5-10 min. Foam roll calves, IT band, quads. These are your priority areas for triathlon running.",
                tips: [
                    CoachingTip(title: "Walk Breaks Are Racing Strategy", detail: "Ironman and 70.3 athletes who walk aid stations and use run-walk strategies often run the same or faster overall finish time. Don't see walking as failure — see it as pacing intelligence.", timing: .duringMainSet),
                    CoachingTip(title: "Long Run Nutrition", detail: "Take a gel or 30g carbs every 45 min on runs over 75 min. Practice this in training. Gut training is real — your intestines learn to process fuel while running.", timing: .nutrition),
                    CoachingTip(title: "Mental Strategy", detail: "On long runs, break the run into thirds mentally. First third: hold back. Second third: settle in. Last third: whatever you have. This prevents the death march of going out too hard.", timing: .duringMainSet)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .run, cue: "As you fatigue, your form degrades: head drops, arms cross body, hips drop back. Every 10 min, do a form check: tall posture, light arms, quick feet.", commonMistake: "Allowing running form to collapse as fatigue sets in — reinforces bad movement patterns"),
                    TechniqueCue(sport: .run, cue: "Downhills: lean forward, small steps, keep feet under hips. Don't brake with your heels — that's how you trash your quads on long courses.", commonMistake: "Heel braking on descents, causing quad-destroying eccentric load")
                ],
                postWorkoutGuidance: "Long runs take 24-48h to fully recover from. Eat a proper meal within 30 min (high carb + protein). Sleep well tonight. Tomorrow should be rest or very easy recovery."
            )

        case .intervals:
            let repCount = experience == .beginner ? 4 : 6
            let repMinutes = 3
            return WorkoutContent(
                title: "Run Intervals (VO2 Max)",
                goal: "Develop your aerobic capacity ceiling — VO2 max. These are the hardest run sessions, but they create the biggest fitness gains.",
                workoutType: .runIntervals,
                intensity: .vo2max,
                distanceKm: distanceKm,
                zones: [
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.25 * 3600, description: "Warm-up"),
                    TrainingZoneBlock(zone: 5, durationSeconds: durationHours * 0.45 * 3600, description: "VO2 max intervals"),
                    TrainingZoneBlock(zone: 1, durationSeconds: durationHours * 0.3 * 3600, description: "Cool-down")
                ],
                warmup: "15 min easy run. Then 4×15s strides at near-sprint pace (90s recovery). You must be warm before intervals.",
                mainSet: """
                    \(repCount)×\(repMinutes) min at hard effort (RPE 8.5-9): faster than 5km race pace, \
                    but controlled enough to maintain form. Recovery = \(repMinutes) min easy jog between reps.

                    You should be breathing very hard. You should dread the next rep. \
                    If reps feel easy, you're going too slow. If you can't finish, you started too fast.
                    """,
                cooldown: "15 min easy jog. Walk last 5 min. Stretch thoroughly.",
                tips: [
                    CoachingTip(title: "Respect the Recovery Interval", detail: "Active recovery (slow jog) between intervals flushes lactate better than standing still. Keep moving, even if it feels slow.", timing: .duringMainSet),
                    CoachingTip(title: "VO2 Max Frequency", detail: "Once per week maximum. These sessions stress your cardiovascular system maximally. Doing too many causes breakdown, not improvement. Trust the plan.", timing: .preWorkout)
                ],
                techniqueCues: [
                    TechniqueCue(sport: .run, cue: "At high speed: maintain tall posture, drive your elbows back (not forward), your foot lands under your hip not in front.", commonMistake: "Reaching forward with the leg to stride longer — this creates a braking force"),
                    TechniqueCue(sport: .run, cue: "Breathe in a rhythm: try 2 steps in, 2 steps out at high intensity. Rhythmic breathing reduces side stitches.", commonMistake: "Irregular breathing causing oxygen supply/demand mismatch and stitches")
                ],
                postWorkoutGuidance: "Rate each interval 1-10 for difficulty. If later intervals are significantly harder than early ones, note this — it's a sign you may need more recovery or slower early-interval pacing."
            )

        default:
            return runContent(type: .easy, phase: phase, experience: experience, durationHours: durationHours)
        }
    }

    // MARK: - Brick Content

    static func brickContent(
        phase: TrainingPhase,
        experience: ExperienceLevel,
        durationHours: Double
    ) -> WorkoutContent {
        let bikeHours = durationHours * 0.75
        let runHours = durationHours * 0.25
        let bikeKm = bikeHours * 28
        let runKm = runHours * 10

        return WorkoutContent(
            title: "Bike → Run Brick",
            goal: "Train your legs to switch from cycling to running. The transition is uncomfortable — the only way to make it easier is to practice it. This is triathlon-specific training you can't skip.",
            workoutType: .bikeThenRun,
            intensity: .moderate,
            distanceKm: bikeKm + runKm,
            zones: [
                TrainingZoneBlock(zone: 1, durationSeconds: bikeHours * 0.15 * 3600, description: "Bike warm-up"),
                TrainingZoneBlock(zone: 2, durationSeconds: bikeHours * 0.65 * 3600, description: "Bike main set"),
                TrainingZoneBlock(zone: 3, durationSeconds: bikeHours * 0.2 * 3600, description: "Bike finish strong"),
                TrainingZoneBlock(zone: 3, durationSeconds: runHours * 3600, description: "Run off bike")
            ],
            warmup: "Start bike easy for 10-15 min. Gradually increase to your target pace. Eat/drink 20 min into bike.",
            mainSet: """
                BIKE (\(String(format: "%.0f", bikeKm)) km): Ride at moderate effort (zone 2-3). \
                Last 10 min: increase to zone 3 — this raises your HR so you begin the run already 'working'.

                TRANSITION (T2): Rack bike, remove helmet, switch to run shoes. \
                Practice fast lace locks. You want this under 60 seconds eventually.

                RUN (\(String(format: "%.1f", runKm)) km): Start immediately — don't stop. \
                First 5 min will feel awful: legs heavy, gait strange. THIS IS NORMAL. \
                Push through it. By min 5-8, your running muscles activate and it smooths out. \
                Run at moderate effort (zone 2-3).
                """,
            cooldown: "Walk 5 min after run. Stretch both cycling and running muscles: hip flexors especially.",
            tips: [
                CoachingTip(title: "The Brick Feeling", detail: "That heavy, wooden leg feeling in the first few minutes of the run is 'brick legs'. It's caused by muscle fiber recruitment shifting from cycling to running. It always gets easier with training — that's why you do bricks.", timing: .duringMainSet),
                CoachingTip(title: "Fast Transitions Win Races", detail: "T2 time is 'free speed'. Lay out your run gear in exactly the same spot each time. Practice putting on shoes while walking. Elastic laces save 10-15 seconds without practice.", timing: .preWorkout),
                CoachingTip(title: "Bike Nutrition Timing", detail: "Don't eat anything in the last 15-20 min of the bike — this avoids stomach sloshing on the run. Time your last gel/food at the 20 min before T2 mark.", timing: .nutrition),
                CoachingTip(title: "Mental Preparation", detail: "Going into a hard run already fatigued from cycling is a mental battle. Pre-decide: 'my run always starts slow for 5 min, then I find my rhythm.' Remove the surprise.", timing: .preWorkout)
            ],
            techniqueCues: [
                TechniqueCue(sport: .run, cue: "Off the bike, your running stride will be shorter than normal — this is correct. Don't force your normal stride length immediately. Let it come back naturally over 5-10 min.", commonMistake: "Forcing normal running stride immediately, causing tripping or hip/knee strain"),
                TechniqueCue(sport: .bike, cue: "Last 2-3 min of bike: spin in easier gear at 100+ rpm. This flushes lactic acid from legs and begins recruiting running muscles before you even dismount.", commonMistake: "Grinding a hard gear to the finish of the bike, arriving at T2 with locked-up legs")
            ],
            postWorkoutGuidance: "Note how long brick legs lasted (typically 3-8 min). This duration should decrease as the season progresses. If it's still 10+ min after 4 brick sessions, increase brick frequency."
        )
    }

    // MARK: - Recovery Content

    static func recoveryContent() -> WorkoutContent {
        WorkoutContent(
            title: "Rest & Recovery",
            goal: "Active or complete rest. Your body gets stronger during recovery, not during training.",
            workoutType: .rest,
            intensity: .recovery,
            distanceKm: nil,
            zones: [],
            warmup: "",
            mainSet: "Complete rest, or gentle 20-30 min walk. No structured exercise.",
            cooldown: "",
            tips: [
                CoachingTip(title: "Sleep is Training", detail: "70-80% of your training adaptations happen during deep sleep. Prioritize 7-9 hours. Sleep is the most powerful recovery tool you have — and it's free.", timing: .preWorkout),
                CoachingTip(title: "Nutrition on Rest Days", detail: "Reduce carbohydrate intake slightly on rest days (no big training to fuel), but don't dramatically undereat. Protein should stay high: 1.6-2g per kg body weight.", timing: .nutrition),
                CoachingTip(title: "Foam Rolling & Mobility", detail: "15-20 min of foam rolling and mobility work on rest days accelerates recovery. Focus on: calves, IT band, hip flexors, thoracic spine.", timing: .postWorkout)
            ],
            techniqueCues: [],
            postWorkoutGuidance: "Recovery is where the magic happens. Trust the process."
        )
    }
}
