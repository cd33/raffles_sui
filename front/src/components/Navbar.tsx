import { ConnectButton } from "@mysten/dapp-kit";
import { useState } from "react";
import { Link, useLocation } from "react-router-dom";

export function Navbar({ title }: { title: string }) {
  const [burgerOpen, setBurgerOpen] = useState(false);
  const location = useLocation();

  return (
    <nav className="sticky top-0 z-50 mx-auto p-6">
      <div className="flex justify-between">
        <div className="flex items-center gap-2">
          <div className="md:hidden mr-2">
            <button
              className="text-gray-300 hover:text-white focus:outline-none"
              onClick={() => setBurgerOpen(!burgerOpen)}
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 6h16M4 12h16M4 18h16"
                />
              </svg>
            </button>
          </div>
          <Link to="/" className="flex items-center gap-2">
            <div className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg">
              <span className="text-white font-bold text-lg">🎰</span>
            </div>
            <h1
              className={`flex text-2xl font-bold tracking-wide text-gray-300 ${
                location.pathname === "/"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
            >
              {title}
            </h1>
          </Link>
          <div className="hidden md:flex items-center gap-6 ml-10">
            <Link
              to="/create-raffle"
              className={`text-xl text-gray-300 ${
                location.pathname === "/create-raffle"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
            >
              Create Raffle
            </Link>
            <Link
              to="/my-raffles"
              className={`text-xl text-gray-300 ${
                location.pathname === "/my-raffles"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
            >
              My Raffles
            </Link>
            <Link
              to="/admin"
              className={`text-xl text-gray-300 ${
                location.pathname === "/admin"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
            >
              Admin
            </Link>
          </div>
        </div>
        {burgerOpen && (
          <div className="fixed inset-0 bg-black bg-opacity-80 z-50 flex flex-col p-8 gap-4 md:hidden">
            <button
              className="cursor-pointer absolute top-4 right-4 text-gray-300 hover:text-white focus:outline-none"
              onClick={() => setBurgerOpen(false)}
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
            <Link
              to="/"
              className={`w-fit text-2xl text-gray-300 my-2 ${
                location.pathname === "/"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
              onClick={() => setBurgerOpen(false)}
            >
              Home
            </Link>
            <Link
              to="/create-raffle"
              className={`w-fit text-2xl text-gray-300 my-2 ${
                location.pathname === "/create-raffle"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
              onClick={() => setBurgerOpen(false)}
            >
              Create Raffle
            </Link>
            <Link
              to="/my-raffles"
              className={`w-fit text-2xl text-gray-300 my-2 ${
                location.pathname === "/my-raffles"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
              onClick={() => setBurgerOpen(false)}
            >
              My Raffles
            </Link>
            <Link
              to="/admin"
              className={`w-fit text-2xl text-gray-300 my-2 ${
                location.pathname === "/admin"
                  ? "text-red-500 hover:text-red-300"
                  : "hover:text-white"
              }`}
              onClick={() => setBurgerOpen(false)}
            >
              Admin
            </Link>
          </div>
        )}
        <div className="flex items-center gap-4">
          <div className="hidden md:flex items-center gap-1 text-sm text-gray-300">
            <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
            <span>Live on SUI Testnet</span>
          </div>
          <ConnectButton className="cursor-pointer" />
        </div>
      </div>
    </nav>
  );
}
