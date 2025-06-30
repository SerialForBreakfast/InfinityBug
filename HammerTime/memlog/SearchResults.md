# InfinityBug – External Reports & Discussions (Collected 2025-06-22)

Below are public threads and articles that describe symptoms matching or closely resembling the *InfinityBug* (remote-press repetition, focus getting stuck, VoiceOver loops, etc.).  Each entry includes a two-sentence summary and a direct link so we can revisit for deeper analysis.

| # | Source & Date | Symptom Summary | Link |
|---|---------------|-----------------|------|
| 1 | Apple Support Community – "Siri Remote moves randomly" (Dec 2021) | Multiple users report Apple TV focus darting uncontrollably as if the remote D-pad were being held down; intermittent, survives reboot, fix is to unpair remote or switch to iPhone Remote. Mirrors our phantom-press loop. | https://discussions.apple.com/thread/253457128 |
| 2 | Apple Support Community – "Remote wheel stuck when clicked" (Jan 2023) | ATV4K users describe left/right clicks latching into continuous scroll until another direction is pressed, identical to our repro steps. Hardware reset & pairing do not solve it. | https://discussions.apple.com/thread/254541618 |
| 3 | Firecore Community – Rewind/skip input turns into continuous rewind on tvOS 17 (Oct 2023) | Heavy press stacking on tvOS 17 triggers unintended long-press behaviour; thread attributes cause to HomePod audio lag but highlights focus backlog under rapid input. | https://community.firecore.com/t/on-tvos-17-has-anyone-else-noticed-the-rewind-behavior-changing-when-using-the-remote/45200 |
| 4 | Apple Vis – VoiceOver cursor looping over same elements in Safari (Mar 2024) | Mac VoiceOver users encounter infinite cursor loop due to ancestor mis-focus, workaround is to disable cursor tracking. Confirms that AX engine can enter loop state on other platforms. | https://www.applevis.com/forum/macos-mac-apps/workaround-voiceover-cursor-getting-stuck-or-looping-over-set-elements-safari |
| 5 | AppleVis – iOS VoiceOver focus jumps to top randomly (July 2023) | Mobile users complain that VO focus resets unpredictably, especially after new content loads; indicates backlog + stale element scenario similar to tvOS engine. | https://www.applevis.com/forum/ios-ipados-gaming/anyone-else-having-problems-voiceover-focus |
| 6 | Apple Support Community – "Remote acting as if buttons are held down" (Mar 2015) | Legacy Apple TV (2nd gen) shows continuous key-repeat behaviour across multiple remotes; users note issue persists after restore → suggests SW focus engine fault rather than IR noise. | https://discussions.apple.com/thread/6896623 |
| 7 | Apple Support Community – "Can't play selected show after tvOS 17.2" (Dec 2023) | Users unable to select UI items after a day's usage until reboot; likely backlog from hidden/unfocussable elements. Though not infinite repeat, shows focus engine degradation under load. | https://discussions.apple.com/thread/255354603 |
| 8 | Apple Support Community – "Apple TV 4K Siri remote acting erratically" (Mar 2023) | Users report remote up/down keys stick causing continuous guide scrolling; reboot & repair remote only temporary – mirrors infinite directional repeat. | https://discussions.apple.com/thread/254732548 |
| 9 | Apple Support Community – "Apple TV 4K 3rd Gen boot-loop – culprit was remote" (Dec 2023) | Extended button press or stuck remote causes tvOS to enter endless reboot cycle until remote out of range – highlights system-level queue flood similar to InfinityBug. | https://discussions.apple.com/thread/255324828 |
| 10 | Apple Support Community – "My Apple TV keeps going back to main menu" (Mar 2018) | Any directional press drops user back to Home, effectively unable to navigate; several users confirm remote/firmware as root cause. | https://discussions.apple.com/thread/8316192 |

## Observations
* Issues span tvOS 15–17 and even macOS/iOS, reinforcing that loop/stale-focus bugs live inside shared AX/Focus engine.
* Threads 1,2,6 explicitly mention **continuous directional movement** identical to InfinityBug.
* No definitive Apple fix is cited; most replies suggest hardware resets → ineffective.

These references can be cited in future documentation and may serve as external validation when filing a radar/FB report. 