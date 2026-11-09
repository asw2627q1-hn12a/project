module ApplicationHelper
  # Enllaç del menú superior: es marca quan és la pàgina actual
  def nav_link(label, path)
    active = current_page?(path)
    link_to label, path, class: ("hn-nav-active" if active), aria: { current: ("page" if active) }
  end
end
