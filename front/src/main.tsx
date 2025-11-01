import { SuiClientProvider, WalletProvider } from "@mysten/dapp-kit";
import "@mysten/dapp-kit/dist/index.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import App from "./App.tsx";
import { Navbar } from "./components/Navbar.tsx";
import "./index.css";
import { networkConfig } from "./networkConfig.ts";
import { AdminPage } from "./pages/AdminPage.tsx";
import CreateRafflePage from "./pages/CreateRafflePage.tsx";
import MyRafflesPage from "./pages/MyRafflesPage.tsx";

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networkConfig} defaultNetwork="localnet">
        <WalletProvider autoConnect>
          <BrowserRouter>
            <div className="min-h-screen">
              <Navbar title="Raffles" />
              <Routes>
                <Route path="/" element={<App />} />
                <Route path="/my-raffles" element={<MyRafflesPage />} />
                <Route path="/create-raffle" element={<CreateRafflePage />} />
                <Route path="/admin" element={<AdminPage />} />
              </Routes>
            </div>
          </BrowserRouter>
        </WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  </StrictMode>,
);
