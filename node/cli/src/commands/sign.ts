import type { Arguments, CommandBuilder } from 'yargs';
import Transport from '@ledgerhq/hw-transport-node-hid';
import Speculos from '@ledgerhq/hw-transport-node-speculos';
import { Common } from 'hw-app-obsidian-common';

type Options = {
  path: string;
  payload: string;
  format: string;
  file: boolean | undefined;
  speculos: boolean;
};

export const command: string = 'sign <path> <payload>';
export const desc: string = 'sign <payload> with the ledger using key <path>';

const formats : string[] = ['json', 'hex', 'base64', 'base64url', 'raw'];
const emptyExcl : any = {};
const formatIsExclusive : any = formats.reduce((excl, fmt) => { excl[fmt] = formats.filter(a=>a!=fmt); return excl; }, emptyExcl);

export const builder: CommandBuilder<Options, Options> = (yargs) =>
  yargs
    .options({
      json: {type: 'boolean'},
      hex: {type: 'boolean'},
      base64: {type: 'boolean'},
      base64url: {type: 'boolean'},
      raw: {type: 'boolean'},
      binary: {type: 'boolean'},
      format: {type: 'string'},
      file: {type: 'boolean'},
      speculos: {type: 'boolean'},
    })
    .conflicts(formatIsExclusive)
    .middleware(argv=>{
      for (const arg of formats) {
        if(argv[arg]) {
          argv['format'] = arg;
        }
      }
      if (argv.format == 'json' || argv.format == 'raw' ) {
        argv.format = 'binary';
      }
      return argv;
    })
    .default('format', 'hex')
    .default('speculos', false)
    .positional('path', {type: 'string', demandOption: true })
    .positional('path', {type: 'string', demandOption: true })
    ;

export const handler = async (argv: Arguments<Options>): Promise<void> => {
  const { path, format, file, speculos } = argv;
  let payloadString = argv.payload;

  if(file) {
    payloadString = await require('fs').promises.readFile(payloadString, 'binary');
  }
  let payload;
  if(format == 'raw' || format == 'json') {
    payload = Buffer.from(payloadString, 'binary');
  } else {
    payload = Buffer.from(payloadString, format as BufferEncoding);
  }

  let transport;
  if (speculos) {
    transport = await Speculos.open({apduPort: 5555});
  } else {
    transport = await Transport.open(undefined);
  }
  let app = new Common(transport, "");

  console.log("Signing: ", payload);

  let res = await app.signTransaction(path, payload);

  process.stdout.write(res.signature+"\n");
  process.exit(0);
}

