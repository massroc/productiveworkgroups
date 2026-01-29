# Productive Work Groups

## Requirements Document

## Overview

A **self-guided** team collaboration web application for conducting Open Systems Theory's "Six Criteria of Productive Work" workshop. The app acts as the facilitator - guiding teams through the process without requiring an experienced external facilitator.

Team members enter their individual scores for each criterion and then discuss the results together to surface obstacles to performance and engagement.

### Key Value Proposition
- **Removes the need for a trained facilitator** - the app guides the workshop flow
- **Self-serve for teams** - any team can run this workshop independently
- Provides context, explanations, and discussion prompts at each step

## Domain Background

Based on research by Drs Fred & Merrelyn Emery, the six intrinsic motivators that determine employee engagement are grouped into two categories:

### Criteria 1-3: Personal Optimization (require balance)
1. **Elbow Room** - Autonomy in making decisions about work methods and timing
2. **Continual Learning** - Two sub-components:
   - 2a. *Setting Goals* - Ability to set your own goals
   - 2b. *Getting Feedback* - Receiving timely, useful feedback
3. **Variety** - Balanced workload avoiding excessive routine or overwhelming demands

### Criteria 4-6: Workplace Climate (maximal - more is better)
4. **Mutual Support and Respect** - Cooperative culture where colleagues help each other
5. **Meaningfulness** - Two sub-components:
   - 5a. *Socially Useful* - Work that contributes value to society
   - 5b. *See Whole Product* - Understanding the complete product/service you contribute to
6. **Desirable Future** - Skill development and career progression opportunities

### Summary: 6 Criteria, 8 Scored Questions
| Criterion # | Question | Parent Criterion | Scale |
|-------------|----------|------------------|-------|
| 1 | Elbow Room | Elbow Room | -5 to +5 |
| 2a | Setting Goals | Continual Learning | -5 to +5 |
| 2b | Getting Feedback | Continual Learning | -5 to +5 |
| 3 | Variety | Variety | -5 to +5 |
| 4 | Mutual Support and Respect | Mutual Support | 0 to 10 |
| 5a | Socially Useful | Meaningfulness | 0 to 10 |
| 5b | See Whole Product | Meaningfulness | 0 to 10 |
| 6 | Desirable Future | Desirable Future | 0 to 10 |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Elixir / Phoenix |
| Database | PostgreSQL |
| Styling | Tailwind CSS |
| Hosting | Fly.io |

## Architecture Considerations

### Design for Reuse

This tool may serve as a foundation for other facilitated team events (e.g., team kick-offs, retrospectives, planning sessions). The architecture should support this by:

**Separating concerns:**
- **Core facilitation engine** - real-time sync, session management, participant tracking
- **Workshop-specific content** - the Six Criteria questions, explanations, scoring scales
- **Reusable UI components** - timers, voting/scoring widgets, discussion prompts, action capture

**Potentially reusable components:**
| Component | Reuse Potential |
|-----------|-----------------|
| Session creation & joining | Any team event |
| Real-time participant sync | Any collaborative activity |
| Waiting room / lobby | Any group event |
| Timed sections with countdown | Any structured workshop |
| Hidden-then-reveal voting | Retrospectives, planning poker, polls |
| Discussion prompts (contextual) | Any facilitated discussion |
| Notes capture per section | Any workshop |
| Action planning with owners | Any team session |
| Facilitator Assistance (on-demand help) | Any guided experience |
| Traffic light visualization | Any scored/rated content |
| Feedback button | Any product |

**Architectural approach:**
- Clean separation between generic facilitation features and Six Criteria-specific content
- Configuration-driven where possible (e.g., questions, scales, timing could be data)
- Component-based UI that can be composed for different workshop types
- Consider a "workshop template" concept for future flexibility

*Note: This doesn't mean over-engineering the MVP - but make conscious decisions that don't paint us into a corner.*

## Scoring System

### Questions 1-4: Balance Scale (from Criteria 1-3)
- **Range**: -5 to +5
- **Optimal**: 0 (balanced)
- **Interpretation**: Negative values indicate too little, positive values indicate too much

| Criterion # | Question | -5 | 0 | +5 |
|-------------|----------|-----|-----|-----|
| 1 | Elbow Room | Too constrained | Just right | Too much autonomy |
| 2a | Setting Goals | No ability to set goals | Balanced | Overwhelmed by goal-setting |
| 2b | Getting Feedback | No feedback | Right amount | Excessive feedback |
| 3 | Variety | Too routine | Good mix | Too chaotic |

### Questions 5-8: Maximal Scale (from Criteria 4-6)
- **Range**: 0 to 10
- **Optimal**: 10 (more is better)

| Criterion # | Question | 0 | 10 |
|-------------|----------|-----|-----|
| 4 | Mutual Support and Respect | No support | Excellent support |
| 5a | Socially Useful | Work feels pointless | Highly valuable to society |
| 5b | See Whole Product | No visibility of outcome | Clear view of full product |
| 6 | Desirable Future | Dead-end | Great growth path |

## Workshop Flow

### 1. Session Setup
- Creator starts a new session
- Shareable link generated for team members to join
- Waiting room shows who has joined

### 2. Introduction Phase
- **Guided overview** of the Six Criteria framework
- Explanation of how the workshop works
- What to expect from the process
- "Ready to begin" confirmation from participants

### 3. Scoring Phase (repeated for each question)
For each of the 8 questions:
1. **Present the criterion** - explanation, what it means, scoring guidance
2. **Individual scoring** - all team members enter their score independently
3. **Scores remain hidden** until everyone has submitted
4. **Reveal** - show all scores with team average and spread
5. **Discussion prompts** - suggested questions to explore
6. **Capture notes** - record key discussion points
7. **Move to next** - when team is ready, proceed to next criterion

### 4. Summary & Reflection
- Overview of all 6 criteria results
- Highlight areas of strength and areas needing attention
- Patterns across the criteria

### 5. Action Planning
- Prompt team to identify concrete actions/next steps
- **Structured list format**:
  - Add discrete action items
  - Optional owner assignment per action
  - Optional link to specific question(s)
- No limit on number of actions, but quality over quantity
- Suggestions on what to focus on available via **Facilitator Assistance** (not shown by default)

### 6. Wrap-up
- Final summary with notes and actions
- Export/save options

## Time Management

### Overview
Workshops can range from under an hour (experienced teams) to a full day (first-timers with rich discussions). A built-in timer helps teams stay on track without being rigid.

**Recommended duration:** 3.5 hours (first-time teams)

### Session Time Setup
- Timer is **optional** - facilitator chooses whether to use one
- If enabled, select from presets or custom duration:
  - **No timer** (default) - no time tracking
  - **2 hours** - Normal session
  - **3.5 hours** - Full session (recommended for first-time teams)
  - **Custom** - Set any duration in 5-minute increments

### Time Allocation

The system divides total time into recommended durations per section:

| Section | % of Total | 3.5 hr Example |
|---------|------------|----------------|
| Introduction | 5% | ~10 min |
| Questions 1-4 (balance) | 35% | ~75 min (~18 min each) |
| Mid-workshop transition | 2% | ~5 min |
| Questions 5-8 (maximal) | 35% | ~75 min (~18 min each) |
| Summary & reflection | 8% | ~15 min |
| Action planning | 12% | ~25 min |
| Buffer/wrap-up | 3% | ~5 min |

*Note: Percentages are guidance - can be refined based on experience.*

### Timer Features

**Visible countdown:**
- Shows time remaining for current section
- Non-intrusive but always visible

**Pacing indicator:**
- Visual cue showing if on track, ahead, or behind
- e.g., progress bar or subtle color shift

**Time exceeded warning:**
- Gentle notification when section time runs out
- "You've used your allocated time for this question. Take as long as you need, but be aware you may need to move faster later."
- Does NOT force advancement - team decides

**Overall time remaining:**
- Always visible: total time left for entire workshop
- Warning when approaching end with sections remaining

### Philosophy
- **Guidance, not enforcement** - timers inform, they don't control
- Teams are free to spend more time where conversations are rich
- The tool helps them understand the trade-offs (more time here = less time later)
- First-time teams often need longer; experienced teams may finish early

### Timer Controls
- Pause timer (e.g., for breaks)
- Adjust remaining time mid-session if needed
- Option to hide timer if team finds it distracting (via Facilitator Assistance?)

---

## Psychological Safety & Privacy

### The Prime Directive (Norm Kerth)

The workshop operates under Norm Kerth's Prime Directive:

> **"Regardless of what we discover, we understand and truly believe that everyone did the best job they could, given what they knew at the time, their skills and abilities, the resources available, and the situation at hand."**

Scores reflect the *system and environment*, not individual failings. Low scores are not accusations - they are opportunities to understand and improve how work is structured.

### Privacy Principles

**Individual scores are visible only to the team:**
- Scores are never shared outside the session participants
- No management dashboards or aggregated org-level reporting of individual data
- What happens in the session stays in the session

**Trust is foundational:**
- Honest responses require safety
- The tool will never be used to evaluate or judge individuals
- Variance in scores is expected and healthy - it reveals different experiences

### Data Visibility Summary

| Data | Who Can See |
|------|-------------|
| Individual scores | Team members in that session only |
| Notes & actions | Team members in that session only |
| Session exists | Only those with the link |

*Note: Multi-team and organizational use cases (aggregated/anonymized insights across teams) are out of scope for MVP and will be discussed separately.*

---

## User Roles & Participation

### Facilitator Role
- The session creator is designated as the **facilitator**
- Facilitator controls workshop progression (starting, advancing questions)
- Facilitator can choose to participate in two modes:
  - **Team member** (default) - participates in scoring like other team members
  - **Observer** - watches the session without entering scores; useful when facilitating for another team

### Participation
- System automatically reveals scores when all *non-observer* participants have submitted
- **Advancing to next question**: Facilitator controls when to move forward
- **Typical team size**: 6-12 participants (optimize UI for this range)

### Handling Dropouts
- If a participant leaves mid-workshop:
  - Their previous scores are retained
  - They are shown as **greyed out** in the participant list
  - Remaining participants can continue without them
  - System only waits for active participants to submit/confirm

## Session Management

### Team Room Concept
Each team has a "team room" - a persistent space containing:
- **Incomplete sessions** - workshops in progress that can be resumed
- **Completed sessions** - finished workshops available for review
- Team room accessed via a shareable link (no account required for MVP)

### Session Lifecycle
1. **Create session** - generates team room if first session, or adds to existing team room
2. **Active session** - participants join and work through questions
3. **Paused/Incomplete** - team can leave and return later via team room link
4. **Completed** - all 8 questions scored, actions captured, available for review

### Session Time Limits
- Sessions have a configurable time limit (TBD - e.g., 7 days?)
- Incomplete sessions remain accessible until expiry
- Completed sessions retained longer (or indefinitely for logged-in users)

### Joining a Session
- Each session has its own unique link
- **New sessions**: Anyone with the link can join before scoring begins
- **In-progress sessions**: Only original participants can rejoin
  - Primary: Automatic recognition via browser localStorage
  - Fallback: Re-enter name, matched against original participant list
- Team room is a conceptual grouping, not a separate navigable page in MVP

## Authentication (Phased)

### Phase 1 (MVP)
- **No authentication required**
- Anyone with a session link can join
- Enter display name to participate

### Phase 2 (Future)
- Optional account creation
- Required to:
  - Save sessions for later review
  - Compare current scores to previous workshops
  - Manage persistent teams

## Data Persistence

### Results Storage
- Workshop results saved to database
- Historical comparison available (for logged-in users)
- Export options: CSV, PDF summary

### Privacy Considerations
- Anonymous sessions: data retained for session duration + configurable period
- Logged-in users: full history retained

## Discussion Approach

- **No in-app chat** - teams discuss via their own channels (in-person, MS Teams, Zoom, etc.)
- The app facilitates scoring and visualization, not the conversation itself
- **Notes feature**: Ability to capture key outcomes/discussion points per criterion
  - Any participant can add notes
  - Notes saved with the session results

## Guided Facilitation Features

Since the app replaces a human facilitator, it should provide:

### For Each Criterion
1. **Clear explanation** of what the criterion means
2. **Scoring guidance** - what the numbers represent
3. **Discussion prompts** - suggested questions to explore after scores are revealed
4. **Interpretation help** - what patterns in scores might indicate

### Facilitation Philosophy
- **Create space, don't spoon-feed** - prompts should open conversation, not direct it
- The goal is to surface **unexpected variance** - where team members have different experiences
- Teams need to talk to uncover what's really going on
- Over-prescriptive prompts can be disempowering and limit organic discovery

### Generic Discussion Prompts
Prompts should be observational and open-ended:

**When scores show variance:**
- "There's a spread in scores here. What might be behind the different experiences?"
- "Some of you scored quite differently - what's that about?"

**When scores are clustered:**
- "The team seems aligned on this one. Does that match your sense?"

**For balance criteria (1-4) when scores trend away from 0:**
- "Most scores lean in one direction. What's contributing to that?"

**General exploration:**
- "What stands out to you looking at these scores?"
- "Anything here that surprises you?"

**Note:** Prompts are suggestions only - teams may skip them entirely if conversation flows naturally.

## Results Visualization

### During Workshop (per question)
- **Simple number display** - each participant's score with their name (like butcher's paper)
- **Team average** indicator
- **Visual spread** - simple indicator showing if team is aligned or dispersed

### Traffic Light Color Coding

Colors indicate how concerning a score is at a glance.

**Balance Scale Questions (1-4)** - where 0 is optimal:

| Score | Color | Meaning |
|-------|-------|---------|
| 0, ±1 | Green | Healthy - close to optimal |
| ±2, ±3 | Amber | Moderate concern |
| ±4, ±5 | Red | Significant concern |

**Maximal Scale Questions (5-8)** - where 10 is optimal:

| Score | Color | Meaning |
|-------|-------|---------|
| 7-10 | Green | Healthy |
| 4-6 | Amber | Moderate concern |
| 0-3 | Red | Significant concern |

### Applying Traffic Lights

- **Individual scores**: Each participant's score shown with traffic light color
- **Team average**: Average score for each question shown with traffic light color
- **Summary view**: All 8 questions at a glance with color indicators

### End of Workshop Summary
- Overview of all 8 questions with traffic light indicators
- Quickly see which areas are healthy (green) vs need attention (red)
- Pattern recognition across the team

## MVP Scope (Phase 1)

### Included in MVP
- [ ] Session creation with shareable link
- [ ] Time allocation setup at session creation
- [ ] Join session via link (name entry only, no account)
- [ ] Waiting room showing participants
- [ ] Introduction/overview screen
- [ ] Scoring interface for all 8 questions
- [ ] Section timers with countdown and warnings
- [ ] Hidden scores until all submit
- [ ] Score reveal with basic visualization
- [ ] Discussion prompts per criterion
- [ ] Basic notes capture per criterion
- [ ] "Ready" confirmation to advance
- [ ] Summary view at end
- [ ] Action planning capture
- [ ] Real-time sync via Phoenix LiveView
- [ ] Feedback button

### Deferred to Later Phases
- [ ] User accounts and authentication
- [ ] Persistent teams
- [ ] Historical comparison
- [ ] Export (CSV, PDF)
- [ ] Previous score comparison
- [ ] Advanced visualizations
- [ ] Usage analytics (aggregated, anonymized)

## Content: Introduction Screen

The introduction is presented before scoring begins. **Skippable** for experienced teams.

### Skip Option
- "Skip intro" button visible for teams who've done this before
- Skipping takes all participants directly to the first question
- Skip requires confirmation: "Has everyone done this workshop before?"

### Screen 1: Welcome

> **Welcome to the Six Criteria Workshop**
>
> This workshop helps your team have a meaningful conversation about what makes work engaging and productive.
>
> Based on forty years of research by Fred and Merrelyn Emery, the Six Criteria are the psychological factors that determine whether work is motivating or draining.
>
> As Fred Emery put it: *"If you don't get these criteria right, there will not be the human interest to see the job through."*

### Screen 2: What You'll Do

> **How This Workshop Works**
>
> You'll work through 8 questions covering 6 criteria together as a team.
>
> For each question:
> 1. Everyone scores independently (your score stays hidden)
> 2. Once everyone has submitted, all scores are revealed
> 3. You discuss what you see - especially any differences
> 4. When ready, you move to the next question
>
> The goal isn't to "fix" scores - it's to **surface and understand** different experiences within your team.

### Screen 3: The Balance Scale (Questions 1-4)

> **Understanding the First Four Questions**
>
> These use a **balance scale** from -5 to +5:
> - These need the right amount - not too much, not too little
> - **0 is optimal** (balanced)
> - Negative means too little, positive means too much
>
> Don't overthink - go with your gut feeling about your current experience.

### Screen 4: Before You Begin

> **Creating a Safe Space**
>
> This workshop operates under the Prime Directive:
>
> *"Regardless of what we discover, we understand and truly believe that everyone did the best job they could, given what they knew at the time, their skills and abilities, the resources available, and the situation at hand."*
>
> Your scores reflect the system and environment - not individual failings. Low scores aren't accusations; they're opportunities to improve how work is structured.
>
> - Be honest - this only works if people share their real experience
> - There are no right or wrong scores
> - Differences are expected - they reveal different experiences
> - Your individual scores are visible only to this team, no one else
>
> **Ready?** When everyone clicks "Ready to Begin", you'll start with the first question.

---

## Content: Mid-Workshop Transition (Before Question 5)

Shown after completing Question 4, before starting Question 5:

> **New Scoring Scale Ahead**
>
> Great progress! You've completed the first four questions.
>
> The next four questions use a different scale: **0 to 10**
> - For these, **more is always better**
> - 10 is optimal
>
> These measure aspects of work where you can never have too much.

---

## On-Demand Facilitator Assistance

A **"Facilitator Assistance"** button available throughout the workshop. When clicked, shows contextual guidance without forcing it on everyone.

### Help Content Examples

**During scoring:**
> Think about your day-to-day experience, not exceptional situations. What's your typical reality?

**During discussion (when scores vary):**
> Wide score differences often reveal that team members have different roles, contexts, or experiences. Try asking: "What's a specific example that led to your score?"

**During discussion (when stuck):**
> If conversation stalls, try: "What would need to change for scores to improve?" But don't force it - sometimes a quick acknowledgment is enough.

**During discussion (general):**
> The facilitator's job is to create space, not fill it. Silence is okay. Let people think.

**During action planning:**
> Consider focusing on areas that showed red or amber scores. But don't ignore patterns - if several related questions scored poorly, there may be a root cause worth addressing.

> Good actions are specific and achievable. "Improve communication" is vague. "Hold a weekly 15-minute team sync" is actionable.

> You don't need to fix everything today. Pick 1-3 actions the team can realistically commit to.

**Note:** Facilitator Assistance appears only when requested - respects the "don't spoon-feed" principle while supporting teams that want more guidance.

---

## Content: Question Explanations

The following explanations will be shown to participants when scoring each question:

### Question 1: Elbow Room
**What it means:** The ability to make decisions about how you do your work in a way that suits your needs. This includes autonomy over methods, timing, and approach.

**Balance consideration:** Autonomy preferences vary - some people thrive with more freedom, others prefer more structure. The optimal score (0) means you have the right amount for you.

### Question 2a: Setting Goals (Continual Learning)
**What it means:** The ability to set your own challenges and targets rather than having them imposed externally. This enables you to maintain an optimal level of challenge.

**Example:** When management sets a Friday deadline but work could finish Wednesday, do you have authority to set your own timeframes?

### Question 2b: Getting Feedback (Continual Learning)
**What it means:** Receiving accurate, timely feedback that enables learning and improvement. Delayed feedback (weeks or months later) provides little value for current work.

**Why it matters:** Without timely feedback, you can't experiment and discover better methods - success becomes chance rather than learning.

### Question 3: Variety
**What it means:** Having a good mix of different tasks and activities. Preferences differ - some people prefer diverse tasks, others favor routine.

**Balance consideration:** The optimal score (0) means you're not stuck with excessive routine tasks, nor overwhelmed by too many demanding activities at once.

### Question 4: Mutual Support and Respect
**What it means:** Working in a cooperative rather than competitive environment where team members help each other during difficult periods.

**What good looks like:** Help flows naturally among peers. Colleagues assist during challenging times without being asked.

### Question 5a: Socially Useful (Meaningfulness)
**What it means:** Your work is worthwhile and contributes value that is recognized by both you and the broader community.

**Reflection:** Can you identify the tangible value your work contributes?

### Question 5b: See Whole Product (Meaningfulness)
**What it means:** Understanding how your specific work contributes to the complete product or service your organization delivers.

**Example:** Like an assembly line worker who knows what happens before and after their station, and understands quality standards - can you connect your individual effort to organizational output?

### Question 6: Desirable Future
**What it means:** Your position offers opportunities to learn new skills and progress in your career. As you master new competencies, your aspirations can grow.

**What good looks like:** Clear paths for development, recognition of growing capabilities, opportunities for increased responsibility.

---

## Visual Design

### Brand Alignment
The app will follow the **Desirable Futures Group** visual design language.

**Reference:** https://www.desirablefutures.group/

### Color Palette (Primary)

| Role | Color | Approx Value |
|------|-------|--------------|
| Background | Near-black | rgb(21, 21, 21) |
| Primary text | White | rgb(255, 255, 255) |
| Accent (primary) | Vibrant green | rgb(66, 210, 53) |
| Accent (secondary) | Electric blue/cyan | rgb(63, 169, 245) |
| Subdued text | Light gray | rgb(176, 176, 176) |
| Dividers/borders | Dark grays | rgb(50-87, 50-87, 50-87) |

**Secondary palette:** To be provided - exact values TBD

### Typography

| Use | Font |
|-----|------|
| Primary | Poppins |
| Secondary/body | Inter |
| Weights | 300 (light) to 900 (heavy) for hierarchy |

### Style Direction

- **Modern & minimalist** - clean, contemporary aesthetic
- **Dark mode** - dark backgrounds with bright accents
- **High contrast** - ensures readability and WCAG compliance
- **Generous whitespace** - breathing room, not cramped
- **Subtle animations** - spring-based transitions for polish
- **Card-based layouts** - consistent spacing and structure

### Traffic Light Colors

The traffic light visualization needs to work within the dark theme:
- **Green**: May align with brand accent green (rgb 66, 210, 53)
- **Amber**: TBD - needs to contrast well on dark background
- **Red**: TBD - needs to contrast well on dark background

*Note: Exact color values to be finalized to ensure accessibility and brand consistency.*

---

## Accessibility

- **Target: WCAG AA compliance**
- Semantic HTML structure
- Full keyboard navigation
- Screen reader compatible
- Sufficient color contrast
- Focus indicators
- Alt text for any images/icons

---

## Error States & Edge Cases

### Connection Issues

**Participant loses connection:**
- Auto-rejoin seamlessly when connection restored
- Pick up exactly where they left off
- No disruption to other participants

**Server/network errors:**
- Show friendly error message
- Attempt automatic reconnection
- Preserve local state where possible

### Participant Edge Cases

**Late joiner (session already in progress):**
- Allowed to join as **observer only**
- Can see scores and discussion but cannot participate
- May be useful for managers or stakeholders observing

**Slow participant (others waiting):**
- **Subtle indicator** shows who hasn't submitted yet
- No automatic nudges or prompts
- Team manages this socially

**Solo participant (everyone else dropped):**
- **Prompt with options**: pause session and wait for others, or continue alone
- Continuing alone has limited value but is allowed

**Participant wants to change score:**
- **Allowed until reveal** - can modify score before all participants have submitted
- Once scores are revealed, they are locked

### Session Edge Cases

**Invalid or expired session link:**
- Silently **redirect to app homepage**
- No error message shown

**Session timeout during workshop:**
- Warn participants before timeout
- Option to extend if still active
- Incomplete sessions remain accessible via original link until expiry

**Minimum participants:**
- Minimum 2 participants to start a session
- Workshop can continue with 1 if others drop (with prompt)

**Maximum participants:**
- **Soft limit** at 15 participants - show warning: "Large groups may make discussion difficult"
- **Hard limit** at 20 participants - cannot exceed
- Allow to proceed past soft limit if team chooses (up to hard limit)

**Session creator leaves:**
- **Ownership transfers** to another active participant automatically
- Session continues without disruption
- No special privileges tied to creator role (all participants equal)

### Input Validation

**Missing score:**
- Cannot submit without selecting a score
- Clear visual indication that score is required

**Notes/actions:**
- Notes are optional
- Actions are optional but encouraged
- No character limits (reasonable max for DB storage)

---

## Feedback

### Feedback Button
- **Always accessible** throughout the workshop (e.g., in footer or menu)
- Opens simple form to capture:
  - What's working well
  - Improvement ideas
  - Bug reports
- Optional: include session context (which section, time spent) to help understand feedback
- Optional: email address for follow-up

### Philosophy
- Make it easy to share thoughts in the moment
- Feedback helps improve the tool for everyone
- Low friction - don't interrupt the workshop flow

---

## Usage Analytics (Future)

Track anonymized usage patterns to refine the tool:

- **Time per section** - how long do teams actually spend on each question?
- **Where do teams exceed time?** - which questions generate the longest discussions?
- **Completion rates** - do teams finish? Where do they drop off?
- **Feature usage** - how often is Facilitator Assistance used? Skip intro?
- **Comparison** - first-time vs repeat teams

*Note: All analytics would be aggregated and anonymized. Individual session data remains private to the team.*

---

## Future Enhancements (Phase 2+)

- User authentication (magic link or email/password)
- Save sessions to account
- Compare current workshop to previous results
- Persistent team management
- Export results (CSV, PDF)
- Usage analytics dashboard (for product improvement)
- Richer analytics and trend visualization
- Mobile-optimized experience

---

*Document Version: 1.1 - Updated timer options and facilitator roles*
*Last Updated: 2026-01-29*
