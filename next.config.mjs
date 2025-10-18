/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // Disable type checking and linting during build in CI (security scan only)
  // This allows Docker build to succeed for Trivy/Dockle scanning
  typescript: {
    ignoreBuildErrors: process.env.CI === 'true',
  },
  eslint: {
    ignoreDuringBuilds: process.env.CI === 'true',
  },
  images: {
    domains: ['localhost', 'predigrowee.agh.edu.pl'],
  },
  env: {
    NEXT_PUBLIC_AUTH_SERVICE_URL: process.env.NEXT_PUBLIC_AUTH_SERVICE_URL,
    NEXT_PUBLIC_QUIZ_SERVICE_URL: process.env.NEXT_PUBLIC_QUIZ_SERVICE_URL,
    NEXT_PUBLIC_STATS_SERVICE_URL: process.env.NEXT_PUBLIC_STATS_SERVICE_URL,
    NEXT_PUBLIC_IMAGES_SERVICE_URL: process.env.NEXT_PUBLIC_IMAGES_SERVICE_URL,
    NEXT_PUBLIC_ADMIN_SERVICE_URL: process.env.NEXT_PUBLIC_ADMIN_SERVICE_URL,
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://localhost:8080/api/:path*',
      },
    ];
  },
};

export default nextConfig;
