import { lazy, Suspense } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'sonner';
import { AuthProvider } from './contexts/AuthContext';
import MainLayout from './components/layout/MainLayout';
import ProtectedRoute from './components/auth/ProtectedRoute';
import LoadingSpinner from './components/common/LoadingSpinner';
import './styles/globals.css';

const LoginPage = lazy(() => import('./pages/LoginPage'));
const RegisterPage = lazy(() => import('./pages/RegisterPage'));
const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const RequestsPage = lazy(() => import('./pages/RequestsPage'));
const RequestDetailPage = lazy(() => import('./pages/RequestDetailPage'));
const TemplatesPage = lazy(() => import('./pages/TemplatesPage'));
const AuditPage = lazy(() => import('./pages/AuditPage'));

const App = () => {
  return (
    <Router>
      <AuthProvider>
        <Toaster richColors position="top-right" />
        <Suspense fallback={<LoadingSpinner />}>
          <Routes>
            <Route path="/login" element={
              <ProtectedRoute requireAuth={false} redirectTo="/dashboard">
                <LoginPage />
              </ProtectedRoute>
            } />
            <Route path="/register" element={
              <ProtectedRoute requireAuth={false} redirectTo="/dashboard">
                <RegisterPage />
              </ProtectedRoute>
            } />
            <Route
              path="/"
              element={
                <ProtectedRoute requireAuth redirectTo="/login">
                  <MainLayout />
                </ProtectedRoute>
              }
            >
              <Route index element={<Navigate to="/dashboard" replace />} />
              <Route path="dashboard" element={<DashboardPage />} />
              <Route path="requests" element={<RequestsPage />} />
              <Route path="requests/:id" element={<RequestDetailPage />} />
              <Route path="templates" element={<TemplatesPage />} />
              <Route path="audit" element={<AuditPage />} />
            </Route>
            <Route path="*" element={<Navigate to="/login" replace />} />
          </Routes>
        </Suspense>
      </AuthProvider>
    </Router>
  );
};

export default App;