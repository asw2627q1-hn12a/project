# Limpiamos datos previos
Submission.destroy_all
User.destroy_all

puts "Creando usuarios..."
users = [
  User.create!(username: "pg", email: "pg@ycombinator.com"),
  User.create!(username: "dhh", email: "dhh@rails.org"),
  User.create!(username: "matz", email: "matz@ruby-lang.org"),
  User.create!(username: "linus", email: "torvalds@linux.org"),
  User.create!(username: "ada_lovelace", email: "ada@analyticalengine.uk")
]

puts "Creando 12 submissions de tipo URL..."
submissions_data = [
  {
    title: "Ruby on Rails 8.0 Released: No PaaS Required",
    url: "https://rubyonrails.org/2024/11/7/rails-8-no-paas-required",
    points: 642,
    user: users[1],
    created_at: 3.hours.ago
  },
  {
    title: "Show HN: We built a Hacker News clone for our ASW course at FIB",
    url: "https://fib.upc.edu/ca/estudis/graus/grau-en-enginyeria-informatica",
    points: 512,
    user: users[0],
    created_at: 1.hour.ago
  },
  {
    title: "SQLite in production is more powerful than you think",
    url: "https://www.sqlite.org/whentouse.html",
    points: 410,
    user: users[3],
    created_at: 6.hours.ago
  },
  {
    title: "Why we moved back to server-side rendering and dropped SPAs",
    url: "https://htmx.org/essays/locality-of-behaviour/",
    points: 355,
    user: users[4],
    created_at: 8.hours.ago
  },
  {
    title: "The Architecture of Open Source Applications",
    url: "https://aosabook.org/en/index.html",
    points: 289,
    user: users[2],
    created_at: 12.hours.ago
  },
  {
    title: "Linux Kernel 6.12 LTS officially announced",
    url: "https://www.kernel.org/",
    points: 240,
    user: users[3],
    created_at: 5.hours.ago
  },
  {
    title: "How to Do Great Work",
    url: "https://paulgraham.com/greatwork.html",
    points: 198,
    user: users[0],
    created_at: 1.day.ago
  },
  {
    title: "Understanding the Ruby Global VM Lock (GVL)",
    url: "https://www.ruby-lang.org/en/documentation/",
    points: 154,
    user: users[2],
    created_at: 9.hours.ago
  },
  {
    title: "A visual guide to Git internals",
    url: "https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain",
    points: 127,
    user: users[4],
    created_at: 15.hours.ago
  },
  {
    title: "PostgreSQL vs SQLite for small to medium web apps",
    url: "https://www.postgresql.org/docs/",
    points: 95,
    user: users[1],
    created_at: 2.days.ago
  },
  {
    title: "The twelve-factor app methodology revisited",
    url: "https://12factor.net/",
    points: 73,
    user: users[4],
    created_at: 20.hours.ago
  },
  {
    title: "MDN Web Docs: Classic HTML Forms without JavaScript",
    url: "https://developer.mozilla.org/en-US/docs/Learn/Forms",
    points: 44,
    user: users[0],
    created_at: 4.hours.ago
  }
]

submissions_data.each do |data|
  Submission.create!(
    title: data[:title],
    url: data[:url],
    points: data[:points],
    submission_type: "url",
    user: data[:user],
    created_at: data[:created_at],
    updated_at: data[:created_at]
  )
end

puts "¡Seeds completados! #{User.count} usuarios y #{Submission.count} submissions creadas."
