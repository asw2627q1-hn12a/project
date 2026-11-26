# Solo añadimos ejemplos que no existen; nunca borramos ni actualizamos datos existentes.

puts "Creando usuarios..."
users_data = [
  {
    username: "pg",
    email: "pg@ycombinator.com",
    about: "Co-founder of Y Combinator and Hacker News. Interested in startups, essays, Lisp, and programming languages."
  },
  {
    username: "dhh",
    email: "dhh@rails.org",
    about: "Creator of Ruby on Rails, partner at 37signals (Basecamp & HEY), and endurance racing driver."
  },
  {
    username: "matz",
    email: "matz@ruby-lang.org",
    about: "Yukihiro Matsumoto. Creator of Ruby. Working on programmer happiness and human-oriented software design."
  },
  {
    username: "linus",
    email: "torvalds@linux.org",
    about: "Creator of the Linux kernel and Git. Open-source software engineer."
  },
  {
    username: "ada_lovelace",
    email: "ada@analyticalengine.uk",
    about: "Mathematician and computing pioneer. Known for work on the Analytical Engine and algorithmic thought."
  }
]

users_data.each do |attributes|
  User.find_or_create_by!(username: attributes[:username]) do |user|
    user.email = attributes[:email]
    user.about = attributes[:about]
  end
end

users_by_username = User.where(username: users_data.map { |u| u[:username] }).index_by(&:username)

puts "Creando submissions de tipo URL..."
submissions_data = [
  {
    title: "Ruby on Rails 8.0 Released: No PaaS Required",
    url: "https://rubyonrails.org/2024/11/7/rails-8-no-paas-required",
    points: 642,
    user: users_by_username.fetch("dhh"),
    created_at: 3.hours.ago
  },
  {
    title: "Show HN: We built a Hacker News clone for our ASW course at FIB",
    url: "https://fib.upc.edu/ca/estudis/graus/grau-en-enginyeria-informatica",
    points: 512,
    user: users_by_username.fetch("pg"),
    created_at: 1.hour.ago
  },
  {
    title: "SQLite in production is more powerful than you think",
    url: "https://www.sqlite.org/whentouse.html",
    points: 410,
    user: users_by_username.fetch("linus"),
    created_at: 6.hours.ago
  },
  {
    title: "Why we moved back to server-side rendering and dropped SPAs",
    url: "https://htmx.org/essays/locality-of-behaviour/",
    points: 355,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 8.hours.ago
  },
  {
    title: "The Architecture of Open Source Applications",
    url: "https://aosabook.org/en/index.html",
    points: 289,
    user: users_by_username.fetch("matz"),
    created_at: 12.hours.ago
  },
  {
    title: "Linux Kernel 6.12 LTS officially announced",
    url: "https://www.kernel.org/",
    points: 240,
    user: users_by_username.fetch("linus"),
    created_at: 5.hours.ago
  },
  {
    title: "How to Do Great Work",
    url: "https://paulgraham.com/greatwork.html",
    points: 198,
    user: users_by_username.fetch("pg"),
    created_at: 1.day.ago
  },
  {
    title: "Understanding the Ruby Global VM Lock (GVL)",
    url: "https://www.ruby-lang.org/en/documentation/",
    points: 154,
    user: users_by_username.fetch("matz"),
    created_at: 9.hours.ago
  },
  {
    title: "A visual guide to Git internals",
    url: "https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain",
    points: 127,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 15.hours.ago
  },
  {
    title: "PostgreSQL vs SQLite for small to medium web apps",
    url: "https://www.postgresql.org/docs/",
    points: 95,
    user: users_by_username.fetch("dhh"),
    created_at: 2.days.ago
  },
  {
    title: "The twelve-factor app methodology revisited",
    url: "https://12factor.net/",
    points: 73,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 20.hours.ago
  },
  {
    title: "MDN Web Docs: Classic HTML Forms without JavaScript",
    url: "https://developer.mozilla.org/en-US/docs/Learn/Forms",
    points: 44,
    user: users_by_username.fetch("pg"),
    created_at: 4.hours.ago
  },
  {
    title: "Designing Data-Intensive Applications",
    url: "https://dataintensive.net/",
    points: 185,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 18.hours.ago
  },
  {
    title: "HTTP/3 Explained: The new transport protocol",
    url: "https://http3-explained.haxx.se/en/",
    points: 110,
    user: users_by_username.fetch("matz"),
    created_at: 1.day.ago
  },
  {
    title: "WebAssembly High-Level Goals and Architecture",
    url: "https://webassembly.org/docs/high-level-goals/",
    points: 85,
    user: users_by_username.fetch("linus"),
    created_at: 2.days.ago
  },
  {
    title: "Reflections on Trusting Trust",
    url: "https://www.cs.cmu.edu/~rdriley/487/papers/Thompson_1984_ReflectionsonTrustingTrust.pdf",
    points: 260,
    user: users_by_username.fetch("pg"),
    created_at: 16.hours.ago
  },
  {
    title: "PostgreSQL tutorial: transactions and rollback",
    url: "https://www.postgresql.org/docs/current/tutorial-transactions.html",
    points: 92,
    user: users_by_username.fetch("linus"),
    created_at: 25.minutes.ago
  },
  {
    title: "A practical guide to HTTP response codes",
    url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status",
    points: 37,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 40.minutes.ago
  },
  {
    title: "Rails Active Storage: uploading files and choosing a storage service",
    url: "https://guides.rubyonrails.org/active_storage_overview.html",
    points: 115,
    user: users_by_username.fetch("dhh"),
    created_at: 90.minutes.ago
  },
  {
    title: "OpenAPI: describing an API with paths and schemas",
    url: "https://spec.openapis.org/oas/v3.0.3.html",
    points: 63,
    user: users_by_username.fetch("matz"),
    created_at: 3.hours.ago
  },
  {
    title: "Git: reviewing changes before merging a branch",
    url: "https://git-scm.com/docs/git-diff",
    points: 48,
    user: users_by_username.fetch("pg"),
    created_at: 10.hours.ago
  },
  {
    title: "Ruby Enumerable: map, select and reduce with small examples",
    url: "https://docs.ruby-lang.org/en/master/Enumerable.html",
    points: 21,
    user: users_by_username.fetch("matz"),
    created_at: 1.day.ago
  },
  {
    title: "Cross-origin requests and the browser preflight",
    url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS",
    points: 74,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 3.days.ago
  },
  {
    title: "Show HN: Reading the source of a small programming language",
    url: "https://craftinginterpreters.com/",
    points: 156,
    user: users_by_username.fetch("pg"),
    created_at: 5.days.ago
  }
]

submissions_data.each do |data|
  Submission.where("LOWER(url) = ?", data[:url].downcase).first_or_create! do |submission|
    submission.assign_attributes(data.merge(submission_type: "url", updated_at: data[:created_at]))
  end
end

puts "Creando submissions de tipo Ask..."
ask_submissions_data = [
  {
    title: "Ask HN: How do you learn a new codebase quickly?",
    text: "Any tips for getting up to speed on a big Rails project?",
    points: 87,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 2.hours.ago
  },
  {
    title: "Ask HN: Is SQLite enough for a side project in production?",
    text: "Thinking of skipping Postgres entirely.",
    points: 54,
    user: users_by_username.fetch("linus"),
    created_at: 5.hours.ago
  },
  {
    title: "Ask HN: What was your favourite course at university?",
    text: "Looking back at your degree, which specific course gave you principles that still guide your engineering decisions today?",
    points: 12,
    user: users_by_username.fetch("matz"),
    created_at: 1.day.ago
  },
  {
    title: "Ask HN: What is your favorite developer tool that nobody talks about?",
    text: "We all know Git, vim, and VS Code, but what small CLI or utility saves you hours every week?",
    points: 68,
    user: users_by_username.fetch("pg"),
    created_at: 7.hours.ago
  },
  {
    title: "Ask HN: How do you structure tests in large Rails applications?",
    text: "System tests vs controller tests vs model tests: what balance works best for long-term maintainability?",
    points: 45,
    user: users_by_username.fetch("dhh"),
    created_at: 14.hours.ago
  },
  {
    title: "Ask HN: Best resources to understand computer architecture deeply?",
    text: "Looking for books, simulators, or courses that bridge logic gates up to modern out-of-order execution pipelines.",
    points: 31,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 1.day.ago
  },
  {
    title: "Ask HN: Favorite paper in computer science or software engineering?",
    text: "Which academic paper changed the way you write code or reason about distributed systems?",
    points: 19,
    user: users_by_username.fetch("matz"),
    created_at: 2.days.ago
  },
  {
    title: "Ask HN: What would you test before your first API demo?",
    text: "Our team is preparing a Rails API demo using Swagger Editor. Which failure cases would you demonstrate alongside the successful requests?",
    points: 36,
    user: users_by_username.fetch("pg"),
    created_at: 15.minutes.ago
  },
  {
    title: "Ask HN: How do you keep uploads after a cloud redeploy?",
    text: "We use PostgreSQL for application data and object storage for images. What checks do you run to confirm both survive a deployment?",
    points: 58,
    user: users_by_username.fetch("dhh"),
    created_at: 35.minutes.ago
  },
  {
    title: "Ask HN: Which small Ruby feature made your code easier to read?",
    text: "I am learning Ruby after Java and C++. I would like examples where a Ruby feature improves readability without hiding the control flow.",
    points: 24,
    user: users_by_username.fetch("matz"),
    created_at: 75.minutes.ago
  },
  {
    title: "Ask HN: How do you review authorization in a REST API?",
    text: "We already authenticate requests with an API key. How do you check that each action can only modify resources owned by the authenticated user?",
    points: 81,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 4.hours.ago
  },
  {
    title: "Ask HN: How do you reproduce intermittent browser test failures?",
    text: "A system test sometimes fails after a redirect. What information helps you distinguish an application bug from a browser or synchronization problem?",
    points: 43,
    user: users_by_username.fetch("linus"),
    created_at: 11.hours.ago
  },
  {
    title: "Ask HN: What makes a useful code review comment?",
    text: "We are starting to review each other's pull requests. How do you explain a concrete problem and its consequence while keeping the feedback short?",
    points: 18,
    user: users_by_username.fetch("pg"),
    created_at: 1.day.ago
  },
  {
    title: "Ask HN: How would you prevent duplicate votes?",
    text: "Two requests from the same user can arrive at the same time. How would you combine model validations, database constraints and a consistent score?",
    points: 96,
    user: users_by_username.fetch("linus"),
    created_at: 2.days.ago
  },
  {
    title: "Ask HN: Which database topic helped you most in a web project?",
    text: "Indexes, transactions and foreign keys all appeared in our Rails project. Which concept became clearer once you used it in an application?",
    points: 29,
    user: users_by_username.fetch("ada_lovelace"),
    created_at: 4.days.ago
  }
]

ask_submissions_data.each do |data|
  Submission.find_or_create_by!(title: data[:title], user: data[:user], submission_type: "ask") do |submission|
    submission.assign_attributes(data.merge(updated_at: data[:created_at]))
  end
end

puts "Creando comentarios anidados y discusiones reproducibles..."

def seed_comment(submission, spec, parent, users_by_username)
  user = users_by_username.fetch(spec[:user])
  is_deleted = spec[:deleted] == true

  existing = submission.comments.where(user: user, parent_id: parent&.id).detect do |c|
    if is_deleted
      c.deleted? || c.body == spec[:body]
    else
      !c.deleted? && c.body == spec[:body]
    end
  end

  comment = existing || begin
    c = submission.comments.new(
      user: user,
      parent: parent,
      points: spec[:points] || 1,
      created_at: spec[:created_at] || Time.current,
      updated_at: spec[:created_at] || Time.current
    )
    if is_deleted
      c.body = ""
      c.deleted_at = spec[:deleted_at] || spec[:created_at] || Time.current
    else
      c.body = spec[:body]
    end
    c.save!
    c
  end

  if spec[:replies].present?
    spec[:replies].each do |reply_spec|
      seed_comment(submission, reply_spec, comment, users_by_username)
    end
  end

  comment
end

comment_threads = [
  # 1. Hilos en Rails 8 URL (6 comentarios, 4 niveles de anidamiento)
  {
    submission_url: "https://rubyonrails.org/2024/11/7/rails-8-no-paas-required",
    user: "matz",
    body: "Congratulations on the Rails 8 release! Really happy to see Ruby 3+ performance improvements and modern defaults shine here.",
    points: 24,
    created_at: 150.minutes.ago,
    replies: [
      {
        user: "dhh",
        body: "Thanks Matz! Couldn't have done it without the continuous GVL and YJIT improvements in recent Ruby versions.",
        points: 18,
        created_at: 120.minutes.ago,
        replies: [
          {
            user: "ada_lovelace",
            body: "The reduction in operational complexity by omitting external dependencies like Redis is a huge design milestone.",
            points: 11,
            created_at: 80.minutes.ago,
            replies: [
              {
                user: "linus",
                body: "Simplicity at the deployment layer is underrated. Fewer moving parts means fewer midnight pages.",
                points: 7,
                created_at: 45.minutes.ago
              }
            ]
          }
        ]
      }
    ]
  },
  {
    submission_url: "https://rubyonrails.org/2024/11/7/rails-8-no-paas-required",
    user: "linus",
    body: "Thruster looks like a neat approach for lightweight HTTP/2 termination in front of Puma containers.",
    points: 14,
    created_at: 100.minutes.ago,
    replies: [
      {
        user: "dhh",
        body: "Exactly, eliminating the need for an external reverse proxy like nginx or caddy for straightforward deployments was the goal.",
        points: 9,
        created_at: 70.minutes.ago
      }
    ]
  },

  # 2. Hilos en SQLite URL (5 comentarios, 3 niveles)
  {
    submission_url: "https://www.sqlite.org/whentouse.html",
    user: "dhh",
    body: "We run SQLite in production for Solid Cache and Solid Queue with exceptional latency and zero maintenance overhead.",
    points: 35,
    created_at: 300.minutes.ago,
    replies: [
      {
        user: "linus",
        body: "Single-file databases with WAL mode and modern NVMe drives eliminate network round trips entirely.",
        points: 22,
        created_at: 240.minutes.ago,
        replies: [
          {
            user: "matz",
            body: "And backing up is just copying a single file or using the SQLite online backup API.",
            points: 15,
            created_at: 180.minutes.ago
          }
        ]
      },
      {
        user: "pg",
        body: "Simplicity usually wins for 95% of web applications that never hit Google scale.",
        points: 12,
        created_at: 200.minutes.ago
      }
    ]
  },
  {
    submission_url: "https://www.sqlite.org/whentouse.html",
    user: "ada_lovelace",
    body: "The deterministic behavior of SQLite also makes testing and local replication remarkably fast and reliable.",
    points: 10,
    created_at: 220.minutes.ago
  },

  # 3. Hilos en SSR / Locality of Behavior (4 comentarios, 3 niveles)
  {
    submission_url: "https://htmx.org/essays/locality-of-behaviour/",
    user: "dhh",
    body: "Server-side rendering has always provided the cleanest mental model for state management.",
    points: 28,
    created_at: 400.minutes.ago,
    replies: [
      {
        user: "matz",
        body: "Agreed. When UI rendering lives next to business rules, you avoid whole classes of synchronization bugs.",
        points: 19,
        created_at: 320.minutes.ago,
        replies: [
          {
            user: "ada_lovelace",
            body: "Locality of behavior makes tracing code during reviews much faster.",
            points: 13,
            created_at: 260.minutes.ago
          }
        ]
      }
    ]
  },
  {
    submission_url: "https://htmx.org/essays/locality-of-behaviour/",
    user: "pg",
    body: "The pendulum in web development constantly swings between fat client and server render. SSR with minimal JS is very pleasant.",
    points: 16,
    created_at: 350.minutes.ago
  },

  # 4. Hilos en Show HN FIB (5 comentarios, caso de comentario soft-deleted con respuestas visibles)
  {
    submission_url: "https://fib.upc.edu/ca/estudis/graus/grau-en-enginyeria-informatica",
    user: "linus",
    body: "Great project for learning web architecture, HTTP semantics, and full-stack development.",
    points: 15,
    created_at: 50.minutes.ago,
    replies: [
      {
        user: "pg",
        body: "Well done to the student team. Re-implementing Hacker News teaches a lot about simplicity and performance.",
        points: 20,
        created_at: 35.minutes.ago
      }
    ]
  },
  {
    submission_url: "https://fib.upc.edu/ca/estudis/graus/grau-en-enginyeria-informatica",
    user: "dhh",
    body: "Initial comment that will be deleted to test soft deletion in threads.",
    deleted: true,
    deleted_at: 20.minutes.ago,
    points: 8,
    created_at: 40.minutes.ago,
    replies: [
      {
        user: "matz",
        body: "This reply is preserved even after the parent comment was deleted, exactly matching Hacker News thread semantics.",
        points: 12,
        created_at: 30.minutes.ago,
        replies: [
          {
            user: "ada_lovelace",
            body: "This confirms logical deletion preserves the conversation structure and downstream replies.",
            points: 6,
            created_at: 15.minutes.ago
          }
        ]
      }
    ]
  },

  # 5. Hilos en Linux Kernel 6.12 (3 comentarios, 3 niveles)
  {
    submission_url: "https://www.kernel.org/",
    user: "ada_lovelace",
    body: "LTS releases provide crucial stability for infrastructure providers and embedded devices.",
    points: 17,
    created_at: 250.minutes.ago,
    replies: [
      {
        user: "linus",
        body: "Indeed. 6.12 brings extended support and many real-time preemption improvements.",
        points: 25,
        created_at: 190.minutes.ago,
        replies: [
          {
            user: "matz",
            body: "The PREEMPT_RT merge is a huge historic milestone for the Linux ecosystem.",
            points: 11,
            created_at: 140.minutes.ago
          }
        ]
      }
    ]
  },

  # 6. Hilos en Ruby GVL (3 comentarios, 3 niveles)
  {
    submission_url: "https://www.ruby-lang.org/en/documentation/",
    user: "linus",
    body: "Thread scheduling in userspace vs kernel threads is always an interesting trade-off.",
    points: 13,
    created_at: 480.minutes.ago,
    replies: [
      {
        user: "matz",
        body: "For I/O bound workloads, releasing the GVL during system calls gives plenty of concurrency without race conditions.",
        points: 20,
        created_at: 400.minutes.ago,
        replies: [
          {
            user: "dhh",
            body: "That's why Puma with a modest thread count has served Rails apps so well for over a decade.",
            points: 10,
            created_at: 310.minutes.ago
          }
        ]
      }
    ]
  },

  # 7. Hilos en Ask HN: How do you learn a new codebase quickly? (7 comentarios, 4 niveles)
  {
    submission_title: "Ask HN: How do you learn a new codebase quickly?",
    user: "dhh",
    body: "Start by reading the domain models and the high-level integration tests. They reveal how the creators intended the system to work.",
    points: 30,
    created_at: 100.minutes.ago,
    replies: [
      {
        user: "linus",
        body: "I always start with git log and commit messages. Understanding why a decision was made is more valuable than just seeing what code does.",
        points: 21,
        created_at: 80.minutes.ago,
        replies: [
          {
            user: "matz",
            body: "Tracing execution paths with a simple logger or debugger while clicking through the UI works wonders too.",
            points: 14,
            created_at: 60.minutes.ago,
            replies: [
              {
                user: "ada_lovelace",
                body: "Sketching a component map of the entry points helps structure your mental model before writing any code.",
                points: 8,
                created_at: 40.minutes.ago
              }
            ]
          }
        ]
      },
      {
        user: "pg",
        body: "Try building and shipping a tiny bugfix on your very first day. Getting momentum immediately reduces intimidation.",
        points: 27,
        created_at: 75.minutes.ago,
        replies: [
          {
            user: "dhh",
            body: "100%. Quick feedback loops build confidence faster than reading documentation for days.",
            points: 16,
            created_at: 50.minutes.ago
          }
        ]
      }
    ]
  },
  {
    submission_title: "Ask HN: How do you learn a new codebase quickly?",
    user: "matz",
    body: "Read the test suite first; good tests act as executable specifications for every module.",
    points: 18,
    created_at: 90.minutes.ago
  },

  # 8. Hilos en Ask HN: Is SQLite enough for a side project in production? (3 comentarios, 3 niveles)
  {
    submission_title: "Ask HN: Is SQLite enough for a side project in production?",
    user: "linus",
    body: "Yes, easily. Modern SQLite can handle tens of thousands of requests per second on a modest virtual server.",
    points: 22,
    created_at: 260.minutes.ago,
    replies: [
      {
        user: "dhh",
        body: "Pair it with Litestream or LiteFS for continuous replication to S3 and you have a bulletproof setup.",
        points: 17,
        created_at: 210.minutes.ago,
        replies: [
          {
            user: "pg",
            body: "Most side projects fail from lack of users, not lack of database scalability. Start simple.",
            points: 14,
            created_at: 160.minutes.ago
          }
        ]
      }
    ]
  },

  # 9. Hilos en Ask HN: What was your favourite course at university? (3 comentarios, 3 niveles)
  {
    submission_title: "Ask HN: What was your favourite course at university?",
    user: "ada_lovelace",
    body: "Compilers and Formal Languages. Seeing how high-level human ideas translate down to machine instructions was magical.",
    points: 26,
    created_at: 1200.minutes.ago,
    replies: [
      {
        user: "matz",
        body: "Same here! It directly inspired me to create Ruby years later.",
        points: 22,
        created_at: 1000.minutes.ago,
        replies: [
          {
            user: "linus",
            body: "Operating Systems for me. Understanding interrupt handling and memory paging changed how I look at software.",
            points: 19,
            created_at: 800.minutes.ago
          }
        ]
      }
    ]
  },

  # 10. Hilos en Ask HN: What is your favorite developer tool that nobody talks about? (2 comentarios, 2 niveles)
  {
    submission_title: "Ask HN: What is your favorite developer tool that nobody talks about?",
    user: "ada_lovelace",
    body: "jq combined with curl. Being able to filter, slice, and reformat JSON directly from the terminal is invaluable.",
    points: 15,
    created_at: 360.minutes.ago,
    replies: [
      {
        user: "linus",
        body: "strace for Linux debugging. When code behaves unexpectedly, seeing the exact syscalls never lies.",
        points: 11,
        created_at: 280.minutes.ago
      }
    ]
  }
]

comment_threads.each do |spec|
  submission = if spec[:submission_url]
    Submission.where("LOWER(url) = ?", spec[:submission_url].downcase).first!
  else
    Submission.find_by!(title: spec[:submission_title], submission_type: "ask")
  end

  seed_comment(submission, spec, nil, users_by_username)
end

# Conversaciones adicionales para recorrer listados, perfiles y respuestas en la demo.
demo_discussions = [
  {
    submission_url: "https://www.postgresql.org/docs/current/tutorial-transactions.html",
    body: "A vote and its score should be committed together. A failed request must leave both unchanged.",
    reply: "I would test a duplicate request as well as a rollback after a validation error."
  },
  {
    submission_url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status",
    body: "The distinction between 401 and 403 is easier to demonstrate using two different users.",
    reply: "An invalid key gives 401. A valid key trying to edit someone else's resource gives 403."
  },
  {
    submission_url: "https://guides.rubyonrails.org/active_storage_overview.html",
    body: "I check the profile after reloading and again after a redeploy before considering an upload complete.",
    reply: "It also helps to test a text file and an oversized image while keeping the previous avatar."
  },
  {
    submission_url: "https://spec.openapis.org/oas/v3.0.3.html",
    body: "A specification is easier to use when its example bodies match the actual controller parameters.",
    reply: "We run the examples through Swagger and compare the status code and JSON with the documented response."
  },
  {
    submission_url: "https://git-scm.com/docs/git-diff",
    body: "I review the staged diff before committing so unrelated local changes stay out of the pull request.",
    reply: "The dependency lockfile deserves a separate look, especially when two branches changed it."
  },
  {
    submission_url: "https://docs.ruby-lang.org/en/master/Enumerable.html",
    body: "Small examples helped me understand how map transforms each item and select keeps matching items.",
    reply: "I would also compare them with Active Record queries, because filtering in Ruby can load unnecessary rows."
  },
  {
    submission_url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS",
    body: "Seeing OPTIONS separately from the authenticated request made the browser behavior much clearer.",
    reply: "The preflight allows the header. The API still validates the key on the actual request."
  },
  {
    submission_url: "https://craftinginterpreters.com/",
    body: "A small interpreter is a manageable project for practicing recursive data structures.",
    reply: "Comment trees in a web application are another example where recursion becomes concrete."
  },
  {
    submission_title: "Ask HN: What would you test before your first API demo?",
    body: "Prepare one successful request, one validation failure and one request with insufficient permissions.",
    reply: "I would add an upload and verify the resulting image in the actual profile page."
  },
  {
    submission_title: "Ask HN: How do you keep uploads after a cloud redeploy?",
    body: "Keep the file in object storage and the attachment metadata in the persistent database.",
    reply: "Then repeat the same read after a deployment and confirm the attachment is still associated with the user."
  },
  {
    submission_title: "Ask HN: Which small Ruby feature made your code easier to read?",
    body: "Guard clauses made controller actions easier for me to follow during code review.",
    reply: "Named scopes also help when their names describe the query and their order is explicit."
  },
  {
    submission_title: "Ask HN: How do you review authorization in a REST API?",
    body: "Send the write request with another user's key even when the web interface hides the edit button.",
    reply: "I also verify that a forged user_id cannot replace the user identified by the header."
  },
  {
    submission_title: "Ask HN: How do you reproduce intermittent browser test failures?",
    body: "Record the browser version and wait for the expected page state before starting the next action.",
    reply: "A failure in session cleanup can affect every test, so the stack trace matters as much as the test name."
  },
  {
    submission_title: "Ask HN: What makes a useful code review comment?",
    body: "Point to a file, describe a failing example and explain the consequence for the user.",
    reply: "Separating a blocking bug from an optional suggestion helps the author decide what to fix first."
  },
  {
    submission_title: "Ask HN: How would you prevent duplicate votes?",
    body: "Use a unique database index on the user and submission pair as well as a model validation.",
    reply: "The score update and vote creation also need to stay consistent when requests run concurrently."
  },
  {
    submission_title: "Ask HN: Which database topic helped you most in a web project?",
    body: "Foreign keys made the ownership relations explicit and caught mistakes beyond the Rails validations.",
    reply: "Transactions became much clearer when I had to keep a vote and its points synchronized."
  }
]

seed_authors = users_data.map { |attributes| attributes[:username] }
demo_discussions.each_with_index do |discussion, index|
  submission = if discussion[:submission_url]
    Submission.where("LOWER(url) = ?", discussion[:submission_url].downcase).first!
  else
    Submission.find_by!(title: discussion[:submission_title], submission_type: "ask")
  end
  elapsed = Time.current - submission.created_at

  seed_comment(submission, {
    user: seed_authors[index % seed_authors.length],
    body: discussion[:body],
    points: 3 + index,
    created_at: submission.created_at + elapsed * 0.2,
    replies: [
      {
        user: seed_authors[(index + 1) % seed_authors.length],
        body: discussion[:reply],
        points: 2 + index,
        created_at: submission.created_at + elapsed * 0.4,
        replies: [
          {
            user: seed_authors[(index + 2) % seed_authors.length],
            body: "I will try that approach and check both the successful request and the failure case.",
            created_at: submission.created_at + elapsed * 0.6
          }
        ]
      }
    ]
  }, nil, users_by_username)

  seed_comment(submission, {
    user: seed_authors[(index + 3) % seed_authors.length],
    body: "Does anyone have a small example of this that could be reproduced in a Rails project?",
    created_at: submission.created_at + elapsed * 0.8
  }, nil, users_by_username)
end

puts "¡Seeds completados! #{User.count} usuarios, #{Submission.count} submissions y #{Comment.count} comentarios en total."
