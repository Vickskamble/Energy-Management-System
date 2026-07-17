import { Zap, LayoutDashboard, BarChart3, Cpu, Receipt, Bell, Settings } from 'lucide-react'

const icons = {
  Overview: LayoutDashboard,
  Consumption: BarChart3,
  Devices: Cpu,
  Billing: Receipt,
  Alerts: Bell,
  Settings,
}

export default function Sidebar({ items, active, onSelect, open }) {
  return (
    <aside
      className={`
        fixed md:static inset-y-0 left-0 z-40 w-60 flex flex-col bg-surface border-r border-border
        transition-transform duration-200
        ${open ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
      `}
    >
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 h-16 border-b border-border shrink-0">
        <div className="w-8 h-8 rounded-lg bg-lime flex items-center justify-center">
          <Zap size={18} className="text-on-lime" />
        </div>
        <span className="font-heading font-bold text-lg text-text-primary tracking-tight">
          Power
        </span>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-6 space-y-1">
        {items.map((item) => {
          const Icon = icons[item]
          const isActive = active === item
          return (
            <button
              key={item}
              onClick={() => onSelect(item)}
              className={`
                w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-medium transition-colors
                ${isActive
                  ? 'bg-lime text-on-lime font-semibold'
                  : 'text-text-muted hover:text-text-primary hover:bg-border/40'
                }
              `}
            >
              <Icon size={18} />
              {item}
            </button>
          )
        })}
      </nav>

      {/* Bottom */}
      <div className="px-6 py-4 border-t border-border text-xs text-text-muted">
        Power v1.0
      </div>
    </aside>
  )
}
