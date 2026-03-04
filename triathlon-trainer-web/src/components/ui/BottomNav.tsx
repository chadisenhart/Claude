import { NavLink } from 'react-router-dom'

const tabs = [
  { to: '/', label: 'Today', icon: '🏠' },
  { to: '/week', label: 'Week', icon: '📅' },
  { to: '/progress', label: 'Progress', icon: '📈' },
  { to: '/settings', label: 'Settings', icon: '⚙️' },
]

export function BottomNav() {
  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 flex safe-area-pb z-50">
      {tabs.map(tab => (
        <NavLink
          key={tab.to}
          to={tab.to}
          end={tab.to === '/'}
          className={({ isActive }) =>
            `flex-1 flex flex-col items-center py-2 text-xs transition-colors ${
              isActive ? 'text-blue-600' : 'text-gray-400'
            }`
          }
        >
          <span className="text-xl mb-0.5">{tab.icon}</span>
          <span>{tab.label}</span>
        </NavLink>
      ))}
    </nav>
  )
}
