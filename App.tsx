import React, { useState, useEffect, FormEvent } from 'react';
import ValueAddedTab from './components/ValueAddedTab';
import LiveDemoTab from './components/LiveDemoTab';
import ErrorBoundary from './components/ErrorBoundary';

const API_BASE = import.meta.env.VITE_API_URL || '';

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'value' | 'demo'>('value');
  const [loggedIn, setLoggedIn] = useState(() => sessionStorage.getItem('loggedIn') === 'true');
  const [username, setUsername] = useState(() => sessionStorage.getItem('username') || '');
  const [loginUsername, setLoginUsername] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [loginLoading, setLoginLoading] = useState(false);

  useEffect(() => {
    if (loggedIn) {
      sessionStorage.setItem('loggedIn', 'true');
      sessionStorage.setItem('username', username);
    } else {
      sessionStorage.removeItem('loggedIn');
      sessionStorage.removeItem('username');
    }
  }, [loggedIn, username]);

  const handleLogin = async (e: FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setLoginLoading(true);
    try {
      const res = await fetch(`${API_BASE}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: loginUsername, password: loginPassword }),
      });
      if (res.ok) {
        const data = await res.json();
        setUsername(data.username);
        setLoggedIn(true);
      } else {
        setLoginError('Invalid username or password');
      }
    } catch {
      setLoginError('Cannot reach server');
    } finally {
      setLoginLoading(false);
    }
  };

  const handleLogout = () => {
    setLoggedIn(false);
    setUsername('');
    setLoginUsername('');
    setLoginPassword('');
  };

  if (!loggedIn) {
    return (
      <div className="min-h-screen bg-[#f5f7fa] flex items-center justify-center">
        <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-sm">
          <div className="text-center mb-6">
            <div className="text-4xl mb-2">🚚</div>
            <h1 className="text-xl font-bold text-teal-700">Fleet Dispatch Assistant</h1>
            <p className="text-gray-500 text-sm mt-1">Sign in to continue</p>
          </div>
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Username</label>
              <input
                type="text"
                value={loginUsername}
                onChange={e => setLoginUsername(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                autoFocus
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
              <input
                type="password"
                value={loginPassword}
                onChange={e => setLoginPassword(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                required
              />
            </div>
            {loginError && (
              <p className="text-red-500 text-sm text-center">{loginError}</p>
            )}
            <button
              type="submit"
              disabled={loginLoading}
              className="w-full bg-teal-700 text-white py-2 rounded-lg font-semibold hover:bg-teal-800 transition-colors disabled:opacity-50"
            >
              {loginLoading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <ErrorBoundary>
    <div className="min-h-screen bg-[#f5f7fa] pb-12">
      {/* Header Container */}
      <div className="max-w-[1400px] mx-auto pt-6 px-4 md:px-8">
        <div className="bg-gradient-to-br from-teal-700 via-teal-600 to-teal-800 rounded-b-2xl shadow-xl p-6 flex items-center justify-between relative overflow-hidden">
          {/* Background Decorative Circles */}
          <div className="absolute top-0 left-0 w-64 h-64 bg-white/5 rounded-full -translate-x-1/2 -translate-y-1/2 blur-2xl pointer-events-none"></div>
          <div className="absolute bottom-0 right-0 w-64 h-64 bg-black/10 rounded-full translate-x-1/2 translate-y-1/2 blur-2xl pointer-events-none"></div>

          {/* Left Icon */}
          <div className="hidden md:flex w-[140px] h-[80px] bg-white rounded-lg p-[3px] shrink-0 items-center justify-center shadow-lg">
             <img src="public/left-icon.png" alt="PB Logo" className="w-full h-full object-contain" />
          </div>

          {/* Title Section */}
          <div className="flex-1 text-center z-10">
            <div className="flex items-center justify-center gap-3">
              <span className="text-2xl">🚚</span>
              <div className="flex flex-col items-center">
                <h1 className="text-2xl md:text-3xl font-bold text-yellow-400 drop-shadow-md tracking-tight">
                  PB - Conversational Chatbot
                </h1>
                <p className="text-indigo-100 text-sm font-medium mt-1 opacity-90">
                  Dispatch & Operations Assistant
                </p>
              </div>
              <span className="text-2xl">⛽</span>
              <span className="bg-yellow-500 text-white px-3 py-1 rounded-full text-xs font-bold shadow-lg border border-yellow-400/50">
                POC4
              </span>
            </div>
          </div>

          {/* Right Section */}
          <div className="flex items-center gap-4 z-10">
            <button
              onClick={handleLogout}
              className="text-white/80 hover:text-white text-sm font-medium bg-white/10 hover:bg-white/20 px-3 py-1.5 rounded-lg transition-colors"
            >
              Logout ({username})
            </button>
            <div className="hidden md:flex w-[140px] h-[80px] bg-white rounded-lg p-[3px] shrink-0 items-center justify-center shadow-lg">
               <img src="public/right-icon.png" alt="Norconsult Telematics" className="w-full h-full object-contain" />
            </div>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="mt-8 mb-6 flex space-x-2 border-b border-gray-200">
          <button
            onClick={() => setActiveTab('value')}
            className={`px-6 py-3 font-semibold text-sm rounded-t-lg transition-all duration-200 flex items-center gap-2 ${
              activeTab === 'value'
                ? 'bg-white text-teal-700 border-b-2 border-teal-700 shadow-sm'
                : 'text-gray-500 hover:text-teal-600 hover:bg-gray-50'
            }`}
          >
            <span className="text-lg">💡</span> Value Added
          </button>
          <button
            onClick={() => setActiveTab('demo')}
            className={`px-6 py-3 font-semibold text-sm rounded-t-lg transition-all duration-200 flex items-center gap-2 ${
              activeTab === 'demo'
                ? 'bg-white text-teal-700 border-b-2 border-teal-700 shadow-sm'
                : 'text-gray-500 hover:text-teal-600 hover:bg-gray-50'
            }`}
          >
            <span className="text-lg">🎯</span> Live Demo
          </button>
        </div>

        {/* Main Content Area */}
        <main className="min-h-[600px]">
          {activeTab === 'value' ? <ValueAddedTab /> : <LiveDemoTab />}
        </main>
      </div>
    </div>
    </ErrorBoundary>
  );
};

export default App;
