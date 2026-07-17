import StatCard from './StatCard'

const stats = [
  { label: 'Current Load', value: '65.9', unit: 'kW', delta: '+4.2% vs avg', variant: 'lime' },
  { label: "Today's Usage", value: '428', unit: 'kWh', delta: '-6.1% vs yesterday' },
  { label: 'Est. Cost Today', value: '₹3,210', delta: '+2.8%' },
  { label: 'Efficiency Score', value: '82', unit: '/100', delta: '+3 pts' },
]

export default function StatRow() {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {stats.map((s) => (
        <StatCard key={s.label} {...s} />
      ))}
    </div>
  )
}
