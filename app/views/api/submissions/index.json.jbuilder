# Llista de submissions. El controlador ha de definir @submissions i @states.
json.array! @submissions, partial: "api/submissions/submission", as: :submission, states: @states
