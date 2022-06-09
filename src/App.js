import './App.css';
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import Navbar from './components/Navbar';
import Home from './components/Home';
import About from './components/About';
import Transak from './components/Transak';
import CrossChain from './components/CrossChain';
import TabGroup from './components/TabGroup';
import React, { useState, useEffect } from 'react'
import PosManager from './abis/PositionManager.json';
import DepPool from './abis/DepositPool.json';
import IERC20Metadata from './abis/IERC20Metadata.json';
import Web3 from "web3/dist/web3.min.js";
import truncateEthAddress from 'truncate-eth-address'

function App() {
  const [account, setAccount] = useState("...");
  const [accountAddr, setAccountAddr] = useState("");
  const [posManager, setPosManager] = useState({});
  const [depPool, setDepPool] = useState({});
  const [token0, setToken0] = useState({});
  const [token1, setToken1] = useState({});

  useEffect(() => {
    loadWeb3()
  }, []);

  const loadWeb3 = async () => {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      await window.ethereum.enable()
    } else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider)
    } else {
      window.alert('Non-Ethereum browser detected. You should consider trying MetaMask!')
    }
    if (window.web3) {
      var accounts = await web3.eth.getAccounts();
      setAccount(truncateEthAddress(accounts[0]));
      setAccountAddr(accounts[0]);
      const networkId = await web3.eth.net.getId();

      console.log("networkId >> " + networkId);
      if (networkId == 3) {
        const _posManager = new web3.eth.Contract(PosManager.abi, "0xC6CB7f8c046756Bd33ad6b322a3b88B0CA9ceC1b");
        setPosManager(_posManager);
        console.log("posManager >>");
        console.log(_posManager);

        const _depPool = new web3.eth.Contract(DepPool.abi, "0x3eFadc5E507bbdA54dDb4C290cc3058DA8163152");
        setDepPool(_depPool);
        console.log("depPool >>");
        console.log(_depPool);
        const token0Addr = await _depPool.methods.token0().call();
        console.log("token0Addr >> " + token0Addr);
        const token1Addr = await _depPool.methods.token1().call();
        console.log("token1Addr >> " + token1Addr);

        const _token0 = new web3.eth.Contract(IERC20Metadata.abi, token0Addr);
        const _token1 = new web3.eth.Contract(IERC20Metadata.abi, token1Addr);

        const symbol0 = await _token0.methods.symbol().call();
        const symbol1 = await _token1.methods.symbol().call();
        console.log("token1Addr >> " + token1Addr);

        setToken0({ address: token0Addr, symbol: symbol0, contract: _token0 });
        setToken1({ address: token1Addr, symbol: symbol1, contract: _token1 });

      } else {
        const posMgrNetworkData = PosManager.networks[networkId];
        if (posMgrNetworkData) {
          const _posManager = new web3.eth.Contract(PosManager.abi, posMgrNetworkData.address.toString());
          setPosManager(_posManager);
        }
        const depPoolNetworkData = DepPool.networks[networkId];
        if (depPoolNetworkData) {
          const _depPool = new web3.eth.Contract(DepPool.abi, depPoolNetworkData.address.toString());
          setDepPool(_depPool);

          const token0Addr = await _depPool.methods.token0().call();
          console.log("token0Addr >> " + token0Addr);
          const token1Addr = await _depPool.methods.token1().call();
          console.log("token1Addr >> " + token1Addr);

          const _token0 = new web3.eth.Contract(IERC20.abi, token0Addr);
          const _token1 = new web3.eth.Contract(IERC20.abi, token1Addr);

          const symbol0 = await _token0.methods.symbol().call();
          const symbol1 = await _token1.methods.symbol().call();
          console.log("token1Addr >> " + token1Addr);
          setToken0({ address: token0Addr, symbol: symbol0, contract: _token0 });
          setToken1({ address: token1Addr, symbol: symbol1, contract: _token1 });
        }
      }

    }

  }

  return (
    <Router>
      <div className="App">
        <Navbar account={account} />
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/about" element={<About />} />
          <Route
            path="/app"
            element={
              <TabGroup
                account={accountAddr}
                token0={token0}
                token1={token1}
                posManager={posManager}
                depPool={depPool}
              />
            }
          />
          <Route path="/transak" element={<Transak />} />
          <Route path="/bridge" element={<CrossChain />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
