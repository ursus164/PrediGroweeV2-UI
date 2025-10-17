/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
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
