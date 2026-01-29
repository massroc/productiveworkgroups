# Script for populating the database with the Six Criteria workshop template.
#
# Run with: mix run priv/repo/seeds.exs
#
# Inside a Docker container:
#   docker compose run --rm app mix run priv/repo/seeds.exs

alias ProductiveWorkgroups.Workshops
alias ProductiveWorkgroups.Workshops.Template

IO.puts("Seeding Six Criteria Workshop template...")

# Check if the template already exists
case Workshops.get_template_by_slug("six-criteria") do
  nil ->
    # Create the Six Criteria workshop template
    {:ok, template} =
      Workshops.create_template(%{
        name: "Six Criteria of Productive Work",
        slug: "six-criteria",
        description: """
        A self-guided workshop based on forty years of research by Fred and Merrelyn Emery.
        The Six Criteria are the psychological factors that determine whether work is
        motivating or draining. Teams work through 8 questions covering 6 criteria to
        surface and understand different experiences within the team.
        """,
        version: "1.0.0",
        default_duration_minutes: 210
      })

    IO.puts("Created template: #{template.name}")

    # Question 1: Elbow Room
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 0,
        title: "Elbow Room",
        criterion_number: "1",
        criterion_name: "Elbow Room",
        explanation: """
        The ability to make decisions about how you do your work in a way that suits your needs.
        This includes autonomy over methods, timing, and approach.

        Autonomy preferences vary - some people thrive with more freedom, others prefer more
        structure. The optimal score (0) means you have the right amount for you.
        """,
        scale_type: "balance",
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0,
        discussion_prompts: [
          "There's a spread in scores here. What might be behind the different experiences?",
          "What aspects of your work give you the most autonomy?",
          "Where do you feel most constrained in making decisions?",
          "What would the ideal level of autonomy look like for you?"
        ],
        scoring_guidance: """
        -5 = Too constrained, no autonomy
         0 = Just right, balanced
        +5 = Too much autonomy, lack of direction
        """
      })

    IO.puts("  Created question: Elbow Room")

    # Question 2a: Setting Goals (Continual Learning)
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 1,
        title: "Setting Goals",
        criterion_number: "2a",
        criterion_name: "Continual Learning",
        explanation: """
        The ability to set your own challenges and targets rather than having them imposed
        externally. This enables you to maintain an optimal level of challenge.

        Example: When management sets a Friday deadline but work could finish Wednesday,
        do you have authority to set your own timeframes?
        """,
        scale_type: "balance",
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0,
        discussion_prompts: [
          "How much control do you have over the goals and targets you work towards?",
          "When do you feel most empowered to set your own challenges?",
          "What would change if you had more ability to set your own goals?",
          "Are there areas where having goals set for you actually helps?"
        ],
        scoring_guidance: """
        -5 = No ability to set goals, all imposed externally
         0 = Good balance of self-set and assigned goals
        +5 = Overwhelmed by goal-setting responsibility
        """
      })

    IO.puts("  Created question: 2a - Setting Goals")

    # Question 2b: Getting Feedback (Continual Learning)
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 2,
        title: "Getting Feedback",
        criterion_number: "2b",
        criterion_name: "Continual Learning",
        explanation: """
        Receiving accurate, timely feedback that enables learning and improvement.
        Delayed feedback (weeks or months later) provides little value for current work.

        Without timely feedback, you can't experiment and discover better methods -
        success becomes chance rather than learning.
        """,
        scale_type: "balance",
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0,
        discussion_prompts: [
          "How quickly do you typically receive feedback on your work?",
          "What types of feedback are most useful for you?",
          "When has feedback helped you improve?",
          "Is there feedback you wish you received but don't?"
        ],
        scoring_guidance: """
        -5 = No feedback, operating in the dark
         0 = Right amount of timely, useful feedback
        +5 = Excessive feedback, micromanagement
        """
      })

    IO.puts("  Created question: 2b - Getting Feedback")

    # Question 3: Variety
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 3,
        title: "Variety",
        criterion_number: "3",
        criterion_name: "Variety",
        explanation: """
        Having a good mix of different tasks and activities. Preferences differ -
        some people prefer diverse tasks, others favor routine.

        The optimal score (0) means you're not stuck with excessive routine tasks,
        nor overwhelmed by too many demanding activities at once.
        """,
        scale_type: "balance",
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0,
        discussion_prompts: [
          "What does your typical day or week look like in terms of variety?",
          "Are there tasks you find too repetitive?",
          "Do you ever feel overwhelmed by switching between too many different things?",
          "What would the ideal mix of tasks look like for you?"
        ],
        scoring_guidance: """
        -5 = Too routine, monotonous work
         0 = Good mix of different tasks
        +5 = Too chaotic, constantly switching contexts
        """
      })

    IO.puts("  Created question: 3 - Variety")

    # Question 4: Mutual Support and Respect
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 4,
        title: "Mutual Support and Respect",
        criterion_number: "4",
        criterion_name: "Mutual Support and Respect",
        explanation: """
        Working in a cooperative rather than competitive environment where team members
        help each other during difficult periods.

        What good looks like: Help flows naturally among peers. Colleagues assist
        during challenging times without being asked.
        """,
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        discussion_prompts: [
          "When have you experienced strong support from colleagues?",
          "What makes this team environment cooperative or competitive?",
          "How does support flow within the team?",
          "What would improve the sense of mutual support?"
        ],
        scoring_guidance: """
         0 = No support, competitive environment
        10 = Excellent support, highly cooperative
        """
      })

    IO.puts("  Created question: 4 - Mutual Support and Respect")

    # Question 5a: Socially Useful (Meaningfulness)
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 5,
        title: "Socially Useful",
        criterion_number: "5a",
        criterion_name: "Meaningfulness",
        explanation: """
        Your work is worthwhile and contributes value that is recognized by both
        you and the broader community.

        Reflection: Can you identify the tangible value your work contributes?
        """,
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        discussion_prompts: [
          "What value does your work contribute to others?",
          "Do you feel your work is recognized as valuable?",
          "How does your work make a difference?",
          "What would make your work feel more meaningful?"
        ],
        scoring_guidance: """
         0 = Work feels pointless
        10 = Highly valuable contribution to society
        """
      })

    IO.puts("  Created question: 5a - Socially Useful")

    # Question 5b: See Whole Product (Meaningfulness)
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 6,
        title: "See Whole Product",
        criterion_number: "5b",
        criterion_name: "Meaningfulness",
        explanation: """
        Understanding how your specific work contributes to the complete product
        or service your organization delivers.

        Example: Like an assembly line worker who knows what happens before and
        after their station, and understands quality standards - can you connect
        your individual effort to organizational output?
        """,
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        discussion_prompts: [
          "How clearly can you see where your work fits in the bigger picture?",
          "Do you understand what happens before and after your contribution?",
          "What would help you see more of the complete picture?",
          "How connected do you feel to the end result?"
        ],
        scoring_guidance: """
         0 = No visibility of where your work fits
        10 = Clear view of entire product/service
        """
      })

    IO.puts("  Created question: 5b - See Whole Product")

    # Question 6: Desirable Future
    {:ok, _} =
      Workshops.create_question(template, %{
        index: 7,
        title: "Desirable Future",
        criterion_number: "6",
        criterion_name: "Desirable Future",
        explanation: """
        Your position offers opportunities to learn new skills and progress in your career.
        As you master new competencies, your aspirations can grow.

        What good looks like: Clear paths for development, recognition of growing
        capabilities, opportunities for increased responsibility.
        """,
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        discussion_prompts: [
          "What growth opportunities do you see in your current role?",
          "How are your developing skills being recognized?",
          "What would help you progress in your career?",
          "What does your ideal future look like here?"
        ],
        scoring_guidance: """
         0 = Dead-end, no growth path
        10 = Great development opportunities
        """
      })

    IO.puts("  Created question: 6 - Desirable Future")

    IO.puts("\nSeed completed successfully!")
    IO.puts("Template '#{template.name}' created with 8 questions.")

  %Template{} = existing ->
    IO.puts("Template 'six-criteria' already exists (id: #{existing.id}). Skipping seed.")
end
