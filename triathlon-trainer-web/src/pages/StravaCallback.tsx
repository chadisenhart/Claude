import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { handleCallback } from '../services/stravaService'

export function StravaCallback() {
  const navigate = useNavigate()
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading')

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const code = params.get('code')
    if (!code) { setStatus('error'); return }

    handleCallback(code).then(ok => {
      setStatus(ok ? 'success' : 'error')
      setTimeout(() => navigate('/settings'), 1500)
    })
  }, [navigate])

  return (
    <div className="min-h-screen flex items-center justify-center bg-white">
      <div className="text-center p-8">
        {status === 'loading' && (
          <>
            <div className="text-5xl mb-4">🟠</div>
            <p className="font-semibold text-gray-700">Connecting to Strava…</p>
          </>
        )}
        {status === 'success' && (
          <>
            <div className="text-5xl mb-4">✅</div>
            <p className="font-semibold text-green-600">Strava connected!</p>
            <p className="text-sm text-gray-400 mt-1">Redirecting…</p>
          </>
        )}
        {status === 'error' && (
          <>
            <div className="text-5xl mb-4">❌</div>
            <p className="font-semibold text-red-500">Connection failed</p>
            <p className="text-sm text-gray-400 mt-1">Redirecting back…</p>
          </>
        )}
      </div>
    </div>
  )
}
