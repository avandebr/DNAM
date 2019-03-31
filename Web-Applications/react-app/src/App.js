import React from 'react'
import {BrowserRouter, Route, Switch} from 'react-router-dom'
import Dialog from 'react-bootstrap-dialog';

import 'bootstrap/dist/css/bootstrap.css'
import './css/index.css'

import { hot } from 'react-hot-loader';

import NavigationBar from './NavigationBar'
import Home from './Home';
import TimestampMetaMask from "./Timestamp/TimestampMetaMask";
import TimestampFree from './Timestamp/TimestampFree';
import VerifyTimestamp from './VerifyTimestamp/VerifyTimestamp';
import DepositFile from './Patenting/DepositFile';
import DepositFolder from './Patenting/DepositFolder';
import Store from './Patenting/Store';
import MyFiles from './Patenting/MyFiles';
import MyRequests from './Patenting/MyRequests'
import About from './About';
//import AdditionalInfo from './AdditionalInfo';

import dotenv from 'dotenv';
dotenv.config();

const App = () => (
  <BrowserRouter>
    {/*<BrowserRouter history={browserHistory}>*/}
    <div>
      <NavigationBar/>
      <Dialog ref={(el) => { window.dialog = el }} />
      <Switch>
        <Route exact path='/' component={Home}/>
        <Route exact path='/Timestamp' component={TimestampFree}/>
        <Route exact path='/PersonalTimestamp' component={TimestampMetaMask}/>
        <Route exact path='/VerifyTimestamp' component={VerifyTimestamp}/>
        <Route exact path='/RegisterSong' component={DepositFile}/>
        <Route exact path='/RegisterAlbum' component={DepositFolder}/>
        <Route exact path='/Store' component={Store}/>
        <Route exact path='/MyFiles' component={MyFiles}/>
        <Route exact path='/MyRequests' component={MyRequests}/>
        <Route exact path='/About' component={About}/>
      </Switch>
    </div>
  </BrowserRouter>
);

export default hot(module)(App);
