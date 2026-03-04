import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAppStore } from './store/useAppStore'
import { BottomNav } from './components/ui/BottomNav'
import { Onboarding } from './pages/Onboarding'
import { Dashboard } from './pages/Dashboard'
import { Week } from './pages/Week'
import { Progress } from './pages/Progress'
import { Settings } from './pages/Settings'
import { StravaCallback } from './pages/StravaCallback'

export default function App() {
  const profile = useAppStore(s => s.profile)

  if (!profile) {
    return (
      <BrowserRouter>
        <Routes>
          <Route path="/strava/callback" element={<StravaCallback />} />
          <Route path="*" element={<Onboarding />} />
        </Routes>
      </BrowserRouter>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/week" element={<Week />} />
        <Route path="/progress" element={<Progress />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/strava/callback" element={<StravaCallback />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <BottomNav />
    </BrowserRouter>
  )
}
