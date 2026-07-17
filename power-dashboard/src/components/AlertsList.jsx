import { AlertTriangle, AlertCircle, Info, XCircle } from 'lucide-react'

const alerts = [
  {
    icon: AlertTriangle,
    color: '#D64545',
    message: 'HVAC — Shop Floor is drawing 12.5 kW, above the 10 kW threshold',
    time: '2 min ago',
  },
  {
    icon: AlertCircle,
    color: '#C3D809',
    message: 'Power factor dropped to 0.78 on Main Motor Line — capacitor bank may need service',
    time: '15 min ago',
  },
  {
    icon: Info,
    color: '#8A8C7E',
    message: 'Today\'s peak demand: 68.2 kW at 10:00 AM',
    time: '3 hours ago',
  },
  {
    icon: XCircle,
    color: '#D64545',
    message: 'Voltage sag detected on Air Compressor — 385V at 08:14 AM',
    time: '4 hours ago',
  },
]

export default function AlertsList() {
  return (
    <div className="bg-white border border-border rounded-xl p-5">
      <h3 className="font-heading font-semibold text-text-primary mb-4">
        Recent Alerts
      </h3>

      <div className="space-y-1">
        {alerts.map((a, i) => (
          <div
            key={i}
            className="flex items-start gap-3 px-4 py-3 rounded-xl bg-surface"
          >
            <a.icon size={16} style={{ color: a.color }} className="mt-0.5 shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-sm text-text-primary leading-snug">{a.message}</p>
              <span className="text-xs text-text-muted mt-0.5 block">{a.time}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
