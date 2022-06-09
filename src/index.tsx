import React from 'react';
import ReactDOM from 'react-dom/client';
import { ChakraProvider } from '@chakra-ui/react';
import App from './App';
import Waitlist from './components/Waitlist/Waitlist';
import reportWebVitals from './reportWebVitals';

import theme from './theme';
import './theme/styles.css';
import '@fontsource/inter';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

/**
 * Boolean that internally toggles
 * between the waitlist component and the whole app
 */
const isWaitlist = true;

root.render(
  <React.StrictMode>
    <ChakraProvider theme={theme}>
      {isWaitlist ? <Waitlist /> : <App />}
    </ChakraProvider>
  </React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
