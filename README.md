# ShellGen

Reverse / bind shell one-liner generator.

D3F4ULT

## Install

```bash
git clone https://github.com/D3F4UL7T/ShellGen.git
cd ShellGen
python3 shellgen.py --list
```

Python 3.6+. No external dependencies.

## Usage

```bash
python3 shellgen.py --list
python3 shellgen.py -t reverse -H 10.10.14.5 -p 4444 -l bash
python3 shellgen.py -t reverse -H 10.10.14.5 -p 443 -l python
python3 shellgen.py -t reverse -H 10.10.14.5 -p 4444 -l nc
python3 shellgen.py -t reverse -H 10.10.14.5 -p 443 -l powershell
python3 shellgen.py -t bind -p 4444 -l python
python3 shellgen.py -t reverse -H 10.10.14.5 -p 4444 -l bash --encode
python3 shellgen.py -k python_reverse_short -H 10.10.14.5 -p 4444
```

## Notes

Lab and authorized use only. Unauthorized access is illegal. Author assumes no liability for misuse.
