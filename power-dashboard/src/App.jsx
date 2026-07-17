import { useState, useEffect } from 'react'
import Sidebar from './components/Sidebar'
import Header from './components/Header'
import StatRow from './components/StatRow'
import ConsumptionChart from './components/ConsumptionChart'
import DeviceList from './components/DeviceList'
import AlertsList from './components/AlertsList'

const navItems = ['Overview', 'Consumption', 'Devices', 'Billing', 'Alerts', 'Settings']

export default function App() {
  const [activeNav, setActiveNav] = useState('Overview')
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [dark, setDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches
    }
    return false
  })

  useEffect(() => {
    document.body.classList.toggle('dark', dark)
  }, [dark])

  return (
    <div className={`flex h-screen overflow-hidden ${dark ? 'dark' : ''}`}>
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-30 bg-[#3A3A32]/30 md:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <Sidebar
        items={navItems}
        active={activeNav}
        onSelect={(item) => { setActiveNav(item); setSidebarOpen(false) }}
        open={sidebarOpen}
      />

      <div className="flex flex-1 flex-col min-w-0">
        <Header
          onMenuClick={() => setSidebarOpen(true)}
          title={activeNav}
          dark={dark}
          onToggleDark={() => setDark(!dark)}
        />

        <main className="flex-1 overflow-y-auto p-6 lg:p-8 space-y-6">
          <StatRow />

          <div className="flex flex-col lg:flex-row gap-6">
            <div className="lg:w-2/3">
              <ConsumptionChart />
            </div>
            <div className="lg:w-1/3">
              <DeviceList />
            </div>
          </div>

          <AlertsList />
        </main>
      </div>
    </div>
  )
}
