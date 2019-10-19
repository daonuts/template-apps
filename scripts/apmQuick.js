const Web3 = require('web3')
const web3 = new Web3(process.env.WEB3_NODE)
const APM = require('@aragon/apm')

const apm = APM(web3, {ensRegistryAddress: process.env.ARAGON_ENS})
  // let templateAPM = await apm.getLatestVersion("daonuts-template.open.aragonpm.eth")

async function main(){
  let repo = await apm.getLatestVersion("airdrop-app.open.aragonpm.eth")
  console.log(repo)
}
main()
