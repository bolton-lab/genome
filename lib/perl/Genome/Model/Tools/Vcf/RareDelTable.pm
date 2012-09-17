package Genome::Model::Tools::Vcf::RareDelTable;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MutationRate - Calculate the mutation rate (per megabase) given a list of mutations (e.g. tier1 SNVs) and a set of regions (e.g. coding space)
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	04/22/2011 by D.K.
#	MODIFIED:	04/22/2011 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it


## Pre-define a ranking system for VEP annotation, where higher = more severe ##
my %vep_class_rank = ();
$vep_class_rank{'-'} = 				0;
$vep_class_rank{'NMD_TRANSCRIPT'} = 		0;
$vep_class_rank{'INTERGENIC'} = 		0;
$vep_class_rank{'UPSTREAM'} = 			1;
$vep_class_rank{'DOWNSTREAM'} = 		2;
$vep_class_rank{'INTRONIC'} = 			3;
$vep_class_rank{'COMPLEX_INDEL'} = 			3;
$vep_class_rank{'5PRIME_UTR'} = 		4;
$vep_class_rank{'3PRIME_UTR'} = 		5;
$vep_class_rank{'WITHIN_NON_CODING_GENE'} = 	6;
$vep_class_rank{'WITHIN_MATURE_miRNA'} = 	7;
$vep_class_rank{'PARTIAL_CODON'} = 		7;
$vep_class_rank{'CODING_UNKNOWN'} = 	        7;
$vep_class_rank{'SYNONYMOUS_CODING'} = 		8;
$vep_class_rank{'STOP_LOST'} = 			9;
$vep_class_rank{'SPLICE_SITE'} = 		10;
$vep_class_rank{'ESSENTIAL_SPLICE_SITE'} = 	11;
$vep_class_rank{'NON_SYNONYMOUS_CODING'} = 	12;
$vep_class_rank{'STOP_GAINED'} = 		13;
$vep_class_rank{'FRAMESHIFT_CODING'} = 		13;

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Vcf::RareDelTable {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		vcf_file	=> { is => 'Text', doc => "Input VCF File" , is_optional => 0},
		phenotype_file	=> { is => 'Text', doc => "Sample Phenotype File with column named phenotype and values 0 or 1" , is_optional => 0},
		vep_file	=> { is => 'Text', doc => "Input VEP Annotation File" , is_optional => 0},
		output_table	=> { is => 'Text', doc => "Output file for deleterious table" , is_optional => 0},
		output_variants	=> { is => 'Text', doc => "Output file for deleterious variants" , is_optional => 0},
		min_read_depth	=> { is => 'Text', doc => "Minimum read depth to accept backfilled wildtype call" , is_optional => 0, default => 10},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Produces a rare/deleterious table by gene from VCF and VEP files"                 
}

sub help_synopsis {
    return <<EOS
This command produces a rare/deleterious table by gene from VCF and VEP files
EXAMPLE:	gmt vcf rare-del-table --vcf-file my.vcf --vep-file my.vep --output-file my.deltable.tsv
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

        my $vcf_file = $self->vcf_file;
	my $output_table = $self->output_table;
	my $output_variants = $self->output_variants;
	my $vep_file = $self->vep_file;
	my $phenotype_file = $self->phenotype_file;

	print "Loading sample phenotypes...\n";
	my %sample_phenotypes = load_phenotypes($phenotype_file);

	print "Loading VEP annotation...\n";
	my %deleterious = load_vep($vep_file);

	## Open output file ##
	
	open(OUTFILE, ">$output_table") or die "Can't open output file: $!\n";
	print OUTFILE "gene\trare_del_vars\tcontrol_variants\tcase_variants\tcontrols_without_var\tcontrols_with_var\tcases_without_var\tcases_with_var\tpct_controls\tpct_cases\n";


	open(VARIANTS, ">$output_variants") or die "Can't open output file: $!\n";
        print VARIANTS "chrom\tposition\tref\tvar\tdbsnp_status\tvaf_cohort\tvaf_controls\tvaf_cases\tvar_control\tvar_cases\tgene\tclass\tcdna_pos\taa_pos\taa_change\tpolyphen\tsift\tcondel\n";
	## Sample name storage ##
	my @sample_names = ();
	my @sample_statuses = ();
	my $numSamples = 0;

	## Counter of rare deleterious variants per gene, and Per-gene hash of samples with rare deleterious mutations ##
	my %gene_rare_del_variants = ();
	my %gene_rare_del_cases = my %gene_rare_del_controls = ();

	## Parse the file ##

	my $input = new FileHandle ($vcf_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		warn "$lineCounter lines parsed...\n" if(!($lineCounter % 100000));

		if(substr($line, 0, 1) eq '#')
		{
			## HEader lines. Ignore unless samples ##
			
			if(substr($line, 0, 6) eq '#CHROM')
			{
				## Get the sample names ##
				my @lineContents = split(/\t/, $line);
				my $numContents = @lineContents;
				
				for(my $colCounter = 9; $colCounter < $numContents; $colCounter++)
				{
					my $sample = $lineContents[$colCounter];
					$stats{'samples'}++;
					$sample_names[$numSamples] = $sample;
					
					if($sample_phenotypes{$sample} && $sample_phenotypes{$sample} eq "1")
					{
						$sample_statuses[$numSamples] = "case";
						$stats{'samples_case'}++;
					}
					else
					{
						$sample_statuses[$numSamples] = "control";
						$stats{'samples_control'}++;
					}
					
					$numSamples++;
				}
				

			}
		}
		else
		{
	                my ($chrom, $position, $id, $ref, $alt, $qual, $filter, $info, $format) = split(/\t/, $line);
			my @lineContents = split(/\t/, $line);
			my $numContents = @lineContents;
			
			$stats{'variants'}++;
			
			if($filter eq '.' || $filter eq 'PASS')
			{
				$stats{'variants_pass'}++;
				## Get the dbSNP Status ##
				
				my $dbsnp_status = "novel";
				my $rs_number = "";
				
				if($id && $id ne ".")
				{
					## We have a dbSNP ##
					$rs_number = $id;
					$dbsnp_status = "known";
					my @infoContents = split(/\;/, $info);
					my %info_values = ();
					foreach my $info_field (@infoContents)
					{
						if($info_field =~ '=')
						{
							my ($name, $value) = split(/\=/, $info_field);
							$info_values{$name} = $value;
						}
						else
						{
							$info_values{$info_field} = 1;
						}
					}
					
					## Common variant is marked as "G5" ##
					
					if($info_values{'G5'} || $info_values{'G5A'})
					{
						## Global MAF of >5% in one or all populations ##
						$dbsnp_status = "common";
					}
					else
					{
						if($info_values{'GMAF'})
						{
							if($info_values{'GMAF'} >= 0.05)
							{
								$dbsnp_status = "common";
							}
							elsif($info_values{'GMAF'} >= 0.01)
							{
								$dbsnp_status = "uncommon";
							}
							else
							{
								$dbsnp_status = "rare";
							}
						}
						else
						{
							## If a very rare mutation ##
							if($info_values{'MUT'} || $info_values{'CLN'})
							{
								$dbsnp_status = "mutation";
							}
						}
					}

				}

				$stats{'variants_pass_dbsnp_' . $dbsnp_status}++;

				if($dbsnp_status eq "rare" || $dbsnp_status eq "novel" || $dbsnp_status eq "mutation")
				{
					my @formatColumns = split(/\:/, $format);		
					
					my %allele_counts = my %allele_counts_case = my %allele_counts_control = ();
					my %variant_samples_by_allele = ();
					
					my $sampleCounter = 0;
					my $numSamplesCalled = 0;
					my $numSamplesMissing = 0;
					
					for(my $colCounter = 9; $colCounter < $numContents; $colCounter++)
					{
						my $gt_string = $lineContents[$colCounter];
						my $sample_name = $sample_names[$sampleCounter];
						my $sample_status = $sample_statuses[$sampleCounter];
						
						my @gtContents = split(/\:/, $gt_string);
						my $numGtContents = @gtContents;
	
						## Parse out the relevant information ##
						my $genotype = "?";
						my $read_depth = 0;
						my $gt_filter_status = "";
						
						for(my $gtCounter = 0; $gtCounter < $numGtContents; $gtCounter++)
						{
							my $column_name = $formatColumns[$gtCounter];
							my $value = $gtContents[$gtCounter];
							
							$read_depth = $value if($column_name eq "DP" && $value ne ".");
							$genotype = $value if($column_name eq "GT" && $value ne ".");
							$gt_filter_status = $value if($column_name eq 'FT');
						}
	
						## Failed per-site genotype filter, so mark as missing ##						
						$genotype = "?" if($gt_filter_status && $gt_filter_status ne "." && $gt_filter_status ne "PASS");
						
						## Reset variants without enough coverage to say wildtype ##					
						$genotype = "?" if($genotype eq "0/0" && $read_depth < $self->min_read_depth);

						
						
						## Print relevant genotype ##
						
						if($genotype && $genotype ne '?')
						{
							$numSamplesCalled++;
							my ($a1, $a2) = split(/\//, $genotype);
							$a1 = code_to_allele($ref, $alt, $a1);
							$a2 = code_to_allele($ref, $alt, $a2);
							$allele_counts{$a1}++;
							$allele_counts{$a2}++;

							## If allele1 isn't reference, count the sample as having a variant ##
							if($a1 ne $ref)
							{
								$variant_samples_by_allele{$a1} .= "\n" if($variant_samples_by_allele{$a1});
								$variant_samples_by_allele{$a1} .= $sampleCounter;
							}
							## If allele2 isn't reference AND it's not the same as allele1, count the sample as having a variant ##
							if($a2 ne $ref && $a2 ne $a1)
							{
								$variant_samples_by_allele{$a2} .= "\n" if($variant_samples_by_allele{$a2});
								$variant_samples_by_allele{$a2} .= $sampleCounter;
							}
							
							if($sample_status eq 'case')
							{
								$allele_counts_case{$a1}++;
								$allele_counts_case{$a2}++;								
							}
							else
							{
								$allele_counts_control{$a1}++;
								$allele_counts_control{$a2}++;																
							}
						}
						else
						{
							$numSamplesMissing++;
						}
						
						$sampleCounter++;					
					}	## Go to next sample ##


					## Get the call rate for this variant ##

					my $call_rate = $numSamplesCalled / ($numSamplesCalled + $numSamplesMissing);

					## Now we should have sample counts for each allele ##

					my @alts = split(/\./, $alt);
					
					foreach my $var (@alts)
					{
						if($allele_counts{$var})
						{
							my $vep_key = join("\t", $chrom, $position, $var);
							
							## Count if deleterious ##
							$stats{'variants_pass_deleterious'}++ if($deleterious{$vep_key});
							
							## Determine allele freq ##
							$allele_counts_case{$var} = 0 if(!$allele_counts_case{$var});
							$allele_counts_control{$var} = 0 if(!$allele_counts_control{$var});
							
							my $vaf = sprintf("%.4f", $allele_counts{$var} / ($numSamplesCalled * 2));
							my $vaf_case = sprintf("%.4f", $allele_counts_case{$var} / ($stats{'samples_case'} * 2));
							my $vaf_control = sprintf("%.4f", $allele_counts_control{$var} / ($stats{'samples_control'} * 2));
							
							## Determine rare status ##
							
#							if($dbsnp_status eq "novel" || $dbsnp_status eq "rare" || $dbsnp_status eq "mutation")
#							{
								if($vaf < 0.05)
								{
									## Rare variant ##
									$stats{'variants_pass_rare'}++;
									
									if($deleterious{$vep_key})
									{
										my ($ens_gene, $gene, $class, $cdna_pos, $protein_pos, $amino_acids, $polyphen, $sift, $condel) = split(/\t/, $deleterious{$vep_key});
										## We have a deleterious rare variant ##
										$stats{'variants_pass_rare_deleterious'}++;
										$gene_rare_del_variants{$gene}++;


										## Get all samples that had this variant ##
										my @samples_with_variant = split(/\n/, $variant_samples_by_allele{$var});
										my $num_cases_with_variant = my $num_controls_with_variant = 0;
										
										foreach my $sample_index (@samples_with_variant)
										{
											my $sample_status = $sample_statuses[$sample_index];
											## IF case, append to gene cases-with-rare-del ##
											if($sample_status eq "case")
											{
												$num_cases_with_variant++;
												$gene_rare_del_cases{$gene} .= "\n" if($gene_rare_del_cases{$gene});
												$gene_rare_del_cases{$gene} .= $sample_index;												
											}
											else
											{
												$num_controls_with_variant++;
												$gene_rare_del_controls{$gene} .= "\n" if($gene_rare_del_controls{$gene});
												$gene_rare_del_controls{$gene} .= $sample_index;
											}
										}
										
										## Print a summary of the variant to the file ##
										
										print VARIANTS join("\t", $chrom, $position, $ref, $var, $dbsnp_status, $vaf, $vaf_control, $vaf_case, $num_controls_with_variant, $num_cases_with_variant, $gene, $class, $cdna_pos, $protein_pos, $amino_acids, $polyphen, $sift, $condel) . "\n";
										
									}
								}
								else
								{
									$stats{'variants_pass_not_rare_in_cohort'}++;
								}
#							}
#							else
#							{
#								
#							}							
						}
						else
						{
							## No pass-filter genotypes showed this alt ##
						}

						

					}


				}
				else
				{
					## No way it's a rare variant ##
					$stats{'variants_pass_not_rare_by_dbsnp'}++;
				}



			}				
		
			

			

		}

                
		

	}
	
	
	print "Outputting gene results...\n";
	
	foreach my $gene (sort keys %gene_rare_del_variants)
	{
		if(length($gene) > 1)
		{
			my %case_counted = my %control_counted = ();
			my $num_cases = my $num_case_variants = 0;
			my $num_controls = my $num_control_variants = 0;
	
			my @cases_variant = split(/\n/, $gene_rare_del_cases{$gene}) if($gene_rare_del_cases{$gene});
			foreach my $sample_index (@cases_variant)
			{
				$num_case_variants++;
				if(!$case_counted{$sample_index})
				{
					$num_cases++;
					$case_counted{$sample_index} = 1;
				}
			}
	
			my @controls_variant = split(/\n/, $gene_rare_del_controls{$gene}) if($gene_rare_del_controls{$gene});
			foreach my $sample_index (@controls_variant)
			{
				$num_control_variants++;
				if(!$control_counted{$sample_index})
				{
					$num_controls++;
					$control_counted{$sample_index} = 1;
				}
			}
			
			my $controls_without = $stats{'samples_control'} - $num_controls;
			my $cases_without = $stats{'samples_case'} - $num_cases;
			
			my $pct_controls = sprintf("%.4f", $num_controls / $stats{'samples_control'});
			my $pct_cases = sprintf("%.4f", $num_cases / $stats{'samples_case'});
			print OUTFILE join("\t", $gene, $gene_rare_del_variants{$gene}, $num_control_variants, $num_case_variants, $controls_without, $num_controls, $cases_without, $num_cases, $pct_controls, $pct_cases) . "\n";			
		}

	}
	
	
	
	close($input);

	close(OUTFILE);
	close(VARIANTS);

	foreach my $key (sort keys %stats)
	{
		print "$stats{$key}\t$key\n";
	}

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub load_phenotypes
{
	my $phenotype_file = shift(@_);

	my %sample_phenotypes = ();

	my $input = new FileHandle ($phenotype_file);
	my $lineCounter = 0;
	
	my @column_names = ();
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		if($lineCounter == 1)
		{
			@column_names = split(/\t/, $line);	
		}
		else
		{
			my @lineContents = split(/\t/, $line);
			my $numContents = @lineContents;
			
			my $sample_name = "";
			my $phenotype = "?";
			
			for(my $colCounter = 0; $colCounter < $numContents; $colCounter++)
			{
				if($colCounter == 0)
				{
					$sample_name = $lineContents[$colCounter];
				}
				elsif($column_names[$colCounter] eq "phenotype")
				{
					$phenotype = $lineContents[$colCounter];
				}
			}
			
			if($sample_name && $phenotype ne "?")
			{
				$sample_phenotypes{$sample_name} = $phenotype;
			}
			
		}
	}
	
	close($input);
	
	return(%sample_phenotypes);
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub load_vep
{
	my $vep_file = shift(@_);

	my %annotation = ();

	my $input = new FileHandle ($vep_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		if(substr($line, 0, 1) ne '#')
		{
			my @lineContents = split(/\t/, $line);
			my ($id, $string, $allele) = split(/\t/, $line);
			my ($chrom, $position) = split(/\:/, $string);
			my $key = join("\t", $chrom, $position, $allele);
	    
			my $ens_gene = $lineContents[3];
			my $class = $lineContents[6];
			my $cdna_pos = $lineContents[7];
			my $cds_pos = $lineContents[8];
			my $protein_pos = $lineContents[9];
			my $amino_acids = $lineContents[10];
			my $extra = $lineContents[13];
	    
			## Reset extra variables
			my $gene = my $polyphen = my $sift = my $condel = "";
	    
			my @extraContents = split(/\;/, $extra);
			foreach my $entry (@extraContents)
			{
				my ($key, $value) = split(/\=/, $entry);
	    
				$gene = $value if($key eq 'HGNC');
				$polyphen = $value if($key eq 'PolyPhen');
				$sift = $value if($key eq 'SIFT');
				$condel = $value if($key eq 'Condel');	
			}
			$gene = $ens_gene if(!$gene);
	    
			my @classes = split(/\,/, $class);
			foreach my $class (@classes)
			{
				if(is_deleterious($class, $polyphen, $sift, $condel))
				{
					if($polyphen || $sift || $condel)
					{
						$annotation{$key} .= "\n" if($annotation{$key});
						$annotation{$key} .= join("\t", $ens_gene, $gene, $class, $cdna_pos, $protein_pos, $amino_acids, $polyphen, $sift, $condel)
					}
					else
					{
						$annotation{$key} .= "\n" if($annotation{$key});
						$annotation{$key} .= join("\t", $ens_gene, $gene, $class, $cdna_pos, "", "", "", "", "")				;
					}									
				}

			}
		}
	}

	close($input);
	
	print "Searching for deleterious...\n";
	
	my %deleterious = ();
	my $num_deleterious = 0;
	## Go through each key that has annotation and choose the top result ##
	
	foreach my $key (keys %annotation)
	{
		$num_deleterious++;
		my @vepResults = split(/\n/, $annotation{$key});
		@vepResults = sort bySeverity @vepResults;
		my $top_result = $vepResults[0];
#		my ($ens_gene, $gene, $class, $cdna_pos, $protein_pos, $amino_acids, $polyphen, $sift, $condel) = split(/\t/, $top_result);
		$deleterious{$key} = $top_result;
	}

	print "$num_deleterious variants met deleterious requirements\n"; 		
	return(%deleterious);
}




#############################################################
# load_vep_results - parses the file
#
#############################################################

sub bySeverity
{
	my ($ens_gene_a, $gene_a, $class_a, $cdna_pos_a, $protein_pos_a, $amino_acids_a, $polyphen_a, $sift_a, $condel_a) = split(/\t/, $a);

	$polyphen_a = 0 if(!$polyphen_a);
	$sift_a = 0 if(!$sift_a);
	$condel_a = 0 if(!$condel_a);
	
	if($polyphen_a)
	{
		my @temp = split(/[\(\)]/, $polyphen_a);
		$polyphen_a = $temp[1];
	}
	if($sift_a)
	{
		my @temp = split(/[\(\)]/, $sift_a);
		$sift_a = $temp[1];
	}
	if($condel_a)
	{
		my @temp = split(/[\(\)]/, $condel_a);
		$condel_a = $temp[1];
	}
	
	my ($ens_gene_b, $gene_b, $class_b, $cdna_pos_b, $protein_pos_b, $amino_acids_b, $polyphen_b, $sift_b, $condel_b) = split(/\t/, $b);

	$polyphen_b = 0 if(!$polyphen_b);
	$sift_b = 0 if(!$sift_b);
	$condel_b = 0 if(!$condel_b);

	if($polyphen_b)
	{
		my @temp = split(/[\(\)]/, $polyphen_b);
		$polyphen_b = $temp[1];
	}
	if($sift_b)
	{
		my @temp = split(/[\(\)]/, $sift_b);
		$sift_b = $temp[1];
	}
	if($condel_b)
	{
		my @temp = split(/[\(\)]/, $condel_b);
		$condel_b = $temp[1];
	}
	
	my $fxn_code_a = fxn_class_code($class_a);
	my $fxn_code_b = fxn_class_code($class_b);
        
        die "Got no code for $class_a\n" if(!$class_a);
        die "Got no code for $class_b\n" if(!$class_b);

	## Sort by function code severity first ##
	$fxn_code_b <=> $fxn_code_a
	or
	$polyphen_b <=> $polyphen_a
	or
	$sift_b <=> $sift_a
	or
	$condel_b <=> $condel_a
}


#############################################################
# load_vep_results - parses the file
#
#############################################################

sub fxn_class_code
{
	my $class = shift(@_);
	
	my @classes = split(/\,/, $class);
	my $num_classes = @classes;
	
	if($num_classes > 1)
	{
		@classes = sort byCode (@classes);
		$class = $classes[0];
	}
	
	foreach my $test_class (keys %vep_class_rank)
	{
		return($vep_class_rank{$test_class}) if($class eq $test_class);
	}
	
        die "No Rank provided for $class\n";
	return(0);
}


#############################################################
# load_vep_results - parses the file
#
#############################################################

sub is_deleterious
{
	my ($class, $polyphen, $sift, $condel) = @_;
	
	if($class eq "ESSENTIAL_SPLICE_SITE")
	{
		return(1);
	}
	elsif($class eq "STOP_GAINED")
	{
		return(1);
	}
	elsif($class eq "NON_SYNONYMOUS_CODING")
	{
		if(is_damaging($polyphen, $sift, $condel))
		{
			return(1);
		}
	}

	return(0);
}


#############################################################
# load_vep_results - parses the file
#
#############################################################

sub is_damaging
{
	my ($polyphen, $sift, $condel) = @_;
	if($polyphen && $polyphen =~ 'damaging')
	{
		return(1);
	}
	if($sift && $sift =~ 'deleterious')
	{
		return(1);
	}
	if($condel && $condel =~ 'deleterious')
	{
		return(1);
	}
	return(0);
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub code_to_allele
{
	my ($ref, $alt, $code) = @_;
	
	my @alt = split(/\,/, $alt);
	
	## Empty ##
	return("?") if($code eq '.');
	
	## Reference ##
	return($ref) if($code eq "0");

	## Variant ##
	return($alt[$code - 1]);	
}


1;
