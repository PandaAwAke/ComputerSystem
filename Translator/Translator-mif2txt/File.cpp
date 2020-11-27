#include "File.h"

File::File(const std::string InputFile, const std::string OutputFile)
	: m_InputFile(InputFile), m_OutputFile(OutputFile)
{

}

bool File::convert(int width, int depth) const
{
	std::ifstream instream(m_InputFile);
	if (!instream.good())
		return false;
	std::ofstream outstream(m_OutputFile, std::ios::trunc);
	if (!outstream.good())
		return false;

	// TODO : is this a must?
	std::string line;
	while (std::getline(instream, line))
	{
		
	}
	return true;
}
