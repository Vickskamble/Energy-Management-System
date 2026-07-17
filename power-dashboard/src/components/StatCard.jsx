import { TrendingUp, TrendingDown } from 'lucide-react'

export default function StatCard({ label, value, unit, delta, variant = 'default' }) {
  const isUp = delta?.startsWith('+')
  const isLime = variant === 'lime'

  return (
    <div
      className={`
        flex flex-col justify-between p-5 rounded-xl border
        ${isLime
          ? 'bg-lime border-lime text-on-lime'
          : 'bg-white border-border text-text-primary'
        }
      `}
    >
      <span className={`text-xs font-medium ${isLime ? 'text-on-lime/70' : 'text-text-muted'}`}>
        {label}
      </span>

      <div className="mt-2 flex items-baseline gap-1">
        <span className="font-mono font-semibold text-3xl tracking-tight">
          {value}
        </span>
        {unit && (
          <span className={`text-sm font-medium ${isLime ? 'text-on-lime/70' : 'text-text-muted'}`}>
            {unit}
          </span>
        )}
      </div>

      {delta && (
        <div className="mt-2 flex items-center gap-1">
          {isUp
            ? <TrendingUp size={14} className={isLime ? 'text-on-lime' : 'text-danger'} />
            : <TrendingDown size={14} className={isLime ? 'text-on-lime' : 'text-danger'} />
          }
          <span className={`text-xs font-medium ${isLime ? 'text-on-lime' : isUp ? 'text-danger' : 'text-danger'}`}>
            {delta}
          </span>
        </div>
      )}
    </div>
  )
}
